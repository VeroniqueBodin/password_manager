import 'dart:typed_data';
import 'password_entry.dart';

abstract class IStorePasswords {
  Future<void> openVault(Uint8List key, String dbPath);
  Future<void> closeVault();
  Future<void> flush();
  Future<void> addOrUpdatePassword(PasswordEntry entry);
  Future<List<PasswordEntry>> getCurrentPasswords();
  Future<String> getPasswordForEntry(String id);
  Future<int> getVaultVersion();
}