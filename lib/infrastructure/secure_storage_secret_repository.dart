import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/i_store_local_secrets.dart';

class SecureStorageSecretRepository implements IStoreLocalSecrets {
  final FlutterSecureStorage _storage;

  SecureStorageSecretRepository(this._storage);

  @override
  Future<void> saveWebDavCredentials(String username, String password) async {
    await _storage.write(key: 'webdav_username', value: username);
    await _storage.write(key: 'webdav_password', value: password);
  }

  @override
  Future<Map<String, String>> getWebDavCredentials() async {
    final username = await _storage.read(key: 'webdav_username') ?? '';
    final password = await _storage.read(key: 'webdav_password') ?? '';
    return {'username': username, 'password': password};
  }

  @override
  Future<void> saveLastSeenVaultVersion(String userHash, int version) async {
    await _storage.write(key: 'vault_version_$userHash', value: version.toString());
  }

  @override
  Future<int> getLastSeenVaultVersion(String userHash) async {
    final versionString = await _storage.read(key: 'vault_version_$userHash');
    if (versionString == null) return 0;

    return int.tryParse(versionString) ?? 0;
  }
}