import 'dart:convert';
import 'dart:typed_data';
import 'package:dargon2_flutter/dargon2_flutter.dart';
import '../domain/i_derive_master_key.dart';
import '../domain/vault_parameters.dart';


class Argon2KeyDerivation implements IDeriveMasterKey {
  @override
  Future<Uint8List> deriveKey(String masterPassword, VaultParameters parameters) async {
    final saltBytes = base64Decode(parameters.salt);

    final result = await argon2.hashPasswordString(
      masterPassword,
      salt: Salt(saltBytes),
      iterations: parameters.iterations,
      memory: parameters.memory,
      parallelism: parameters.parallelism,
      length: 32,
      type: Argon2Type.id,
      version: Argon2Version.V13,
    );

    return Uint8List.fromList(result.rawBytes);
  }
}