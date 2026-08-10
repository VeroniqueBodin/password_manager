import 'dart:convert';
import 'dart:typed_data';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../domain/i_store_passwords.dart';
import '../domain/password_entry.dart';

class SqlCipherPasswordRepository implements IStorePasswords {
  Database? _db;

  @override
  Future<void> openVault(Uint8List key, String dbPath) async {
    final stringKey = base64Encode(key);

    _db = await openDatabase(
      dbPath,
      password: stringKey,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
            '''
          CREATE TABLE passwords (
            id TEXT,
            title TEXT,
            username TEXT,
            password TEXT,
            url TEXT,
            notes TEXT,
            created_at TEXT,
            is_current INTEGER
          )
          '''
        );
        await db.execute('CREATE TABLE vault_metadata (key TEXT PRIMARY KEY, value INTEGER)');
        await db.execute('INSERT INTO vault_metadata (key, value) VALUES (\'vault_version\', 1)');
      },
    );
  }

  @override
  Future<void> closeVault() async {
    await _db?.close();
    _db = null;
  }

  @override
  Future<void> flush() async {
    if (_db != null && _db!.isOpen) {
      await _db!.execute('PRAGMA wal_checkpoint(FULL);');
    }
  }

  @override
  Future<void> addOrUpdatePassword(PasswordEntry entry) async {
    if (_db == null || !_db!.isOpen) throw Exception('Le coffre est fermé.');
    await _db!.transaction((txn) async {
      await txn.update('passwords', {'is_current': 0}, where: 'id = ?', whereArgs: [entry.id]);
      await txn.insert('passwords', {
        'id': entry.id,
        'title': entry.title,
        'username': entry.username,
        'password': entry.password,
        'url': entry.url,
        'notes': entry.notes,
        'created_at': entry.createdAt.toIso8601String(),
        'is_current': entry.isCurrent ? 1 : 0,
      });
      await txn.execute('UPDATE vault_metadata SET value = value + 1 WHERE key = \'vault_version\'');
    });
  }

  @override
  Future<List<PasswordEntry>> getCurrentPasswords() async {
    if (_db == null || !_db!.isOpen) throw Exception('Le coffre est fermé.');
    final List<Map<String, dynamic>> maps = await _db!.query(
      'passwords',
      columns: ['id', 'title', 'username', 'url', 'notes', 'created_at', 'is_current'],
      where: 'is_current = ?',
      whereArgs: [1],
    );

    return maps.map((map) => PasswordEntry(
      id: map['id'] as String,
      title: map['title'] as String,
      username: map['username'] as String,
      password: '', // Non chargé en mémoire pour sécurité RAM
      url: map['url'] as String,
      notes: map['notes'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      isCurrent: (map['is_current'] as int) == 1,
    )).toList();
  }

  @override
  Future<String> getPasswordForEntry(String id) async {
    if (_db == null || !_db!.isOpen) throw Exception('Le coffre est fermé.');
    final result = await _db!.query(
      'passwords',
      columns: ['password'],
      where: 'id = ? AND is_current = 1',
      whereArgs: [id],
    );
    if (result.isNotEmpty) return result.first['password'] as String;
    throw Exception('Mot de passe introuvable en base.');
  }

  @override
  Future<int> getVaultVersion() async {
    if (_db == null || !_db!.isOpen) throw Exception('Le coffre est fermé.');
    final result = await _db!.query('vault_metadata', columns: ['value'], where: 'key = ?', whereArgs: ['vault_version']);
    if (result.isNotEmpty) return result.first['value'] as int;
    return 1;
  }
}