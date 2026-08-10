abstract class IStoreLocalSecrets {
  Future<void> saveWebDavCredentials(String username, String password);

  Future<Map<String, String>> getWebDavCredentials();

  Future<void> saveLastSeenVaultVersion(String userHash, int version);

  Future<int> getLastSeenVaultVersion(String userHash);
}