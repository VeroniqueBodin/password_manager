import 'dart:io';
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

  Future<void> createAndUploadNewVault(
      String userHash,
      String masterPassword,
      VaultParameters parameters,
      String localDbPath,
      ) async {
    await _synchronizer.uploadParameters(userHash, parameters);

    final masterKey = await _keyDerivation.deriveKey(masterPassword, parameters);

    await _passwordRepository.openVault(masterKey);

    await _secretRepository.saveLastSeenVaultVersion(userHash, 1);

    await _passwordRepository.closeVault();

    final localFile = File(localDbPath);
    await _synchronizer.uploadVaultFile(userHash, localFile);
  }

  Future<void> unlockVault(
      String masterPassword,
      String userHash,
      bool isOnline,
      String localDbPath,
      String tempDbPath,
      ) async {
    if (isOnline) {
      final parameters = await _synchronizer.fetchParameters(userHash);

      final masterKey = await _keyDerivation.deriveKey(masterPassword, parameters);

      final tempFile = await _synchronizer.downloadVaultFile(userHash, tempDbPath);

      await _passwordRepository.openVault(masterKey);

      final remoteVersion = await _passwordRepository.getVaultVersion();
      final localVersion = await _secretRepository.getLastSeenVaultVersion(userHash);

      await _passwordRepository.closeVault();

      if (remoteVersion < localVersion) {
        tempFile.deleteSync();
        throw Exception('Alerte de sécurité : Tentative de Rollback détectée.');
      }

      final localFile = File(localDbPath);
      if (localFile.existsSync()) {
        localFile.deleteSync();
      }
      tempFile.renameSync(localDbPath);

      await _secretRepository.saveLastSeenVaultVersion(userHash, remoteVersion);

      await _passwordRepository.openVault(masterKey);

    } else {
      final credentials = await _secretRepository.getWebDavCredentials();
      if (credentials.isEmpty) {
        throw Exception('Impossible de se connecter hors-ligne sans première initialisation.');
      }

      final localFile = File(localDbPath);
      if (!localFile.existsSync()) {
        throw Exception('Aucun coffre local trouvé pour le mode hors-ligne.');
      }

      final fallbackParameters = await _synchronizer.fetchParameters(userHash);
      final masterKey = await _keyDerivation.deriveKey(masterPassword, fallbackParameters);

      await _passwordRepository.openVault(masterKey);
    }
  }

  Future<void> lockVault() async {
    await _passwordRepository.closeVault();
  }
}