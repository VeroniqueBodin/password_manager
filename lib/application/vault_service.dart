import 'dart:convert';
import 'dart:io';
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

  VaultService(
      this._keyDerivation,
      this._passwordRepository,
      this._synchronizer,
      this._secretRepository,
      );

  IStorePasswords get repository => _passwordRepository;

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
          throw Exception('Alerte de sécurité : Tentative de Rollback détectée.');
        }

        final localFile = File(localDbPath);
        if (localFile.existsSync()) {
          localFile.deleteSync();
        }
        tempFile.renameSync(localDbPath);

        await _secretRepository.saveLastSeenVaultVersion(userHash, remoteVersion);

        await _passwordRepository.openVault(masterKey, localDbPath);
      } finally {
        masterKey.fillRange(0, masterKey.length, 0);
      }

    } else {
      final credentials = await _secretRepository.getWebDavCredentials();
      if (credentials.isEmpty) {
        throw Exception('Impossible de se connecter hors-ligne sans première initialisation.');
      }

      if (!File(localDbPath).existsSync()) {
        throw Exception('Aucun coffre local trouvé pour le mode hors-ligne.');
      }

      if (!File(localMetaPath).existsSync()) {
        throw Exception('Métadonnées introuvables pour le mode hors-ligne.');
      }

      final fallbackParameters = VaultParameters.fromJson(jsonDecode(await File(localMetaPath).readAsString()));
      final masterKey = await _keyDerivation.deriveKey(masterPassword, fallbackParameters);

      try {
        await _passwordRepository.openVault(masterKey, localDbPath);
      } finally {
        masterKey.fillRange(0, masterKey.length, 0);
      }
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
    } finally {
      masterKey.fillRange(0, masterKey.length, 0);
    }
  }

  Future<void> syncVaultToCloud(String userHash) async {
    final dbDir = await getDatabasesPath();
    final localDbPath = p.join(dbDir, 'vault_$userHash.db');

    await _synchronizer.createRollingBackup(userHash);

    final localFile = File(localDbPath);
    await _synchronizer.uploadVaultFile(userHash, localFile);
  }

  Future<void> lockVault() async {
    await _passwordRepository.closeVault();
  }
}