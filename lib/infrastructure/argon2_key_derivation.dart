import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../domain/i_derive_master_key.dart';
import '../domain/vault_parameters.dart';

class Argon2KeyDerivation implements IDeriveMasterKey {
  @override
  Future<Uint8List> deriveKey(String masterPassword, VaultParameters parameters) async {
    return await Isolate.run(() async {
      final saltBytes = base64Decode(parameters.salt);

      final algorithm = Argon2id(
        memory: parameters.memory,
        iterations: parameters.iterations,
        parallelism: parameters.parallelism,
        hashLength: 32,
      );

      final secretKey = await algorithm.deriveKeyFromPassword(
        password: masterPassword,
        nonce: saltBytes,
      );

      final bytes = await secretKey.extractBytes();
      return Uint8List.fromList(bytes);
    });
  }
}