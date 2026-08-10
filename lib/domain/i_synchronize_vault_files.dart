import 'dart:io';
import 'vault_parameters.dart';

abstract class ISynchronizeVaultFiles {
  Future<VaultParameters> fetchParameters(String userHash);

  Future<void> uploadParameters(String userHash, VaultParameters parameters);

  Future<File> downloadVaultFile(String userHash, String destinationPath);

  Future<void> uploadVaultFile(String userHash, File localVaultFile);

  Future<void> createRollingBackup(String userHash);
}