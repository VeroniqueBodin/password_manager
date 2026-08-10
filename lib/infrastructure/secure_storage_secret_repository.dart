import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/i_store_local_secrets.dart';

class SecureStorageSecretRepository implements IStoreLocalSecrets {
  final FlutterSecureStorage _storage;

  const SecureStorageSecretRepository(this._storage);

  @override
  Future<void> saveWebDavCredentials(String username, String password) async {
    await _storage.write(key: 'webdav_user', value: username);
    await _storage.write(key: 'webdav_pwd', value: password);
  }

  @override
  Future<Map<String, String>> getWebDavCredentials() async {
    final user = await _storage.read(key: 'webdav_user');
    final pwd = await _storage.read(key: 'webdav_pwd');
    if (user != null && pwd != null) {
      return {'username': user, 'password': pwd};
    }
    return {};
  }

  @override
  Future<void> saveLastSeenVaultVersion(String userHash, int version) async {
    await _storage.write(key: 'version_$userHash', value: version.toString());
  }

  @override
  Future<int> getLastSeenVaultVersion(String userHash) async {
    final versionStr = await _storage.read(key: 'version_$userHash');
    if (versionStr != null) {
      return int.tryParse(versionStr) ?? 1;
    }
    return 1;
  }

  @override
  Future<void> saveLastUsername(String username) async {
    await _storage.write(key: 'last_username', value: username);
  }

  @override
  Future<String?> getLastUsername() async {
    return await _storage.read(key: 'last_username');
  }

  @override
  Future<void> saveSessionMasterKey(Uint8List masterKey) async {
    await _storage.write(key: 'session_master_key', value: base64Encode(masterKey));
  }

  @override
  Future<Uint8List?> getSessionMasterKey() async {
    final base64Key = await _storage.read(key: 'session_master_key');
    if (base64Key != null) {
      return base64Decode(base64Key);
    }
    return null;
  }

  @override
  Future<void> clearSessionMasterKey() async {
    await _storage.delete(key: 'session_master_key');
    await _storage.delete(key: 'last_master_login_time');
  }

  @override
  Future<void> saveLastMasterLoginTimestamp(DateTime timestamp) async {
    await _storage.write(key: 'last_master_login_time', value: timestamp.toIso8601String());
  }

  @override
  Future<DateTime?> getLastMasterLoginTimestamp() async {
    final timeStr = await _storage.read(key: 'last_master_login_time');
    if (timeStr != null) {
      return DateTime.tryParse(timeStr);
    }
    return null;
  }
}