import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../domain/i_derive_master_key.dart';
import '../domain/i_store_passwords.dart';
import '../domain/i_synchronize_vault_files.dart';
import '../domain/i_store_local_secrets.dart';
import '../domain/vault_parameters.dart';

class VaultService {
  final IDeriveMasterKey _keyDerivation;
  final IStorePasswords _passwordRepository;
  final ISynchronizeVaultFiles _synchronizer;
  final IStoreLocalSecrets _secretRepository;

  static const int biometricSessionWindowMinutes = 10;

  bool isAuthenticatingBiometrically = false;

  VaultService(
      this._keyDerivation,
      this._passwordRepository,
      this._synchronizer,
      this._secretRepository,
      );

  IStorePasswords get repository => _passwordRepository;

  Future<bool> isBiometricSessionValid() async {
    final lastLogin = await _secretRepository.getLastMasterLoginTimestamp();
    if (lastLogin == null) return false;

    final difference = DateTime.now().difference(lastLogin);
    if (difference.inMinutes >= biometricSessionWindowMinutes) {
      await _secretRepository.clearSessionMasterKey();
      return false;
    }

    final key = await _secretRepository.getSessionMasterKey();
    return key != null;
  }

  Future<void> unlockVault(String masterPassword, String userHash, bool isOnline) async {
    final dbDir = await getDatabasesPath();
    final localDbPath = p.join(dbDir, 'vault_$userHash.db');
    final tempDbPath = p.join(dbDir, 'temp_$userHash.db');
    final localMetaPath = p.join(dbDir, 'meta_$userHash.json');

    if (isOnline) {
      final parameters = await _synchronizer.fetchParameters(userHash);
      await File(localMetaPath).writeAsString(jsonEncode(parameters.toJson()));

      final masterKey = await _keyDerivation.deriveKey(masterPassword, parameters);

      try {
        final tempFile = await _synchronizer.downloadVaultFile(userHash, tempDbPath);
        await _passwordRepository.openVault(masterKey, tempDbPath);

        final remoteVersion = await _passwordRepository.getVaultVersion();
        final localVersion = await _secretRepository.getLastSeenVaultVersion(userHash);

        await _passwordRepository.closeVault();

        if (remoteVersion < localVersion) {
          if (tempFile.existsSync()) tempFile.deleteSync();
          await _passwordRepository.openVault(masterKey, localDbPath);
          await syncVaultToCloud(userHash);
        } else {
          final localFile = File(localDbPath);
          if (localFile.existsSync()) localFile.deleteSync();
          tempFile.renameSync(localDbPath);
          await _secretRepository.saveLastSeenVaultVersion(userHash, remoteVersion);
          await _passwordRepository.openVault(masterKey, localDbPath);
        }

        await _secretRepository.saveSessionMasterKey(masterKey);
        await _secretRepository.saveLastMasterLoginTimestamp(DateTime.now());

      } finally {
        masterKey.fillRange(0, masterKey.length, 0);
      }
    } else {
      final credentials = await _secretRepository.getWebDavCredentials();
      if (credentials.isEmpty) {
        throw Exception('Impossible de se connecter hors-ligne sans première initialisation.');
      }

      if (!File(localDbPath).existsSync() || !File(localMetaPath).existsSync()) {
        throw Exception('Coffre local ou métadonnées introuvables.');
      }

      final fallbackParameters = VaultParameters.fromJson(jsonDecode(await File(localMetaPath).readAsString()));
      final masterKey = await _keyDerivation.deriveKey(masterPassword, fallbackParameters);
      try {
        await _passwordRepository.openVault(masterKey, localDbPath);
        await _secretRepository.saveSessionMasterKey(masterKey);
        await _secretRepository.saveLastMasterLoginTimestamp(DateTime.now());
      } finally {
        masterKey.fillRange(0, masterKey.length, 0);
      }
    }
  }

  Future<void> unlockVaultWithBiometrics(String userHash) async {
    final isValid = await isBiometricSessionValid();
    if (!isValid) {
      throw Exception('Session biométrique expirée (10 minutes dépassées). Mot de passe maître requis.');
    }

    final masterKey = await _secretRepository.getSessionMasterKey();
    if (masterKey == null) {
      throw Exception('Clé de session introuvable.');
    }

    final dbDir = await getDatabasesPath();
    final localDbPath = p.join(dbDir, 'vault_$userHash.db');

    if (!File(localDbPath).existsSync()) {
      throw Exception('Aucune base de données locale trouvée.');
    }

    try {
      await _passwordRepository.openVault(masterKey, localDbPath);
    } finally {
      masterKey.fillRange(0, masterKey.length, 0);
    }
  }

  Future<void> createAndUploadNewVault(String userHash, String masterPassword, VaultParameters parameters) async {
    final dbDir = await getDatabasesPath();
    final localDbPath = p.join(dbDir, 'vault_$userHash.db');
    final localMetaPath = p.join(dbDir, 'meta_$userHash.json');

    await _synchronizer.uploadParameters(userHash, parameters);
    await File(localMetaPath).writeAsString(jsonEncode(parameters.toJson()));

    final masterKey = await _keyDerivation.deriveKey(masterPassword, parameters);

    try {
      await _passwordRepository.openVault(masterKey, localDbPath);
      await _secretRepository.saveLastSeenVaultVersion(userHash, 1);
      await _passwordRepository.closeVault();

      final localFile = File(localDbPath);
      await _synchronizer.uploadVaultFile(userHash, localFile);

      await _secretRepository.saveSessionMasterKey(masterKey);
      await _secretRepository.saveLastMasterLoginTimestamp(DateTime.now());
    } finally {
      masterKey.fillRange(0, masterKey.length, 0);
    }
  }

  Future<void> syncVaultToCloud(String userHash) async {
    final dbDir = await getDatabasesPath();
    final localDbPath = p.join(dbDir, 'vault_$userHash.db');

    await _passwordRepository.flush();
    await _synchronizer.createRollingBackup(userHash);

    final localFile = File(localDbPath);
    await _synchronizer.uploadVaultFile(userHash, localFile);
  }

  Future<void> lockVault() async {
    await _passwordRepository.closeVault();
  }
}