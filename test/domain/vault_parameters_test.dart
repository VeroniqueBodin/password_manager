import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/domain/vault_parameters.dart';

void main() {
  group('VaultMeta', () {
    test('doit se serialiser correctement en JSON', () {
      final meta = VaultParameters(
        schemaVersion: 1,
        cipher: 'sqlcipher',
        kdf: 'argon2id',
        memory: 131072,
        iterations: 3,
        parallelism: 4,
        salt: 'un_sel_aleatoire_en_base64',
        createdAt: DateTime.utc(2026, 8, 4),
      );

      final json = meta.toJson();

      expect(json['schema_version'], 1);
      expect(json['cipher'], 'sqlcipher');
      expect(json['kdf'], 'argon2id');
      expect(json['memory'], 131072);
      expect(json['iterations'], 3);
      expect(json['parallelism'], 4);
      expect(json['salt'], 'un_sel_aleatoire_en_base64');
      expect(json['created_at'], '2026-08-04T00:00:00.000Z');
    });

    test('doit se deserialiser correctement depuis un JSON', () {
      final jsonMap = {
        'schema_version': 1,
        'cipher': 'sqlcipher',
        'kdf': 'argon2id',
        'memory': 131072,
        'iterations': 3,
        'parallelism': 4,
        'salt': 'un_sel_aleatoire_en_base64',
        'created_at': '2026-08-04T00:00:00.000Z',
      };

      final meta = VaultParameters.fromJson(jsonMap);

      expect(meta.schemaVersion, 1);
      expect(meta.cipher, 'sqlcipher');
      expect(meta.kdf, 'argon2id');
      expect(meta.memory, 131072);
      expect(meta.iterations, 3);
      expect(meta.parallelism, 4);
      expect(meta.salt, 'un_sel_aleatoire_en_base64');
      expect(meta.createdAt, DateTime.utc(2026, 8, 4));
    });
  });
}