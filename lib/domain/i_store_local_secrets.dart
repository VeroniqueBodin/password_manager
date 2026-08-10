import 'dart:typed_data';

abstract class IStoreLocalSecrets {
  Future<void> saveWebDavCredentials(String username, String password);
  Future<Map<String, String>> getWebDavCredentials();

  Future<void> saveLastSeenVaultVersion(String userHash, int version);
  Future<int> getLastSeenVaultVersion(String userHash);

  Future<void> saveLastUsername(String username);
  Future<String?> getLastUsername();
  Future<void> saveSessionMasterKey(Uint8List masterKey);
  Future<Uint8List?> getSessionMasterKey();
  Future<void> clearSessionMasterKey();

  Future<void> saveLastMasterLoginTimestamp(DateTime timestamp);
  Future<DateTime?> getLastMasterLoginTimestamp();
}