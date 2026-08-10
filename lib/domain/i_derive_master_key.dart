import 'dart:typed_data';
import 'vault_parameters.dart';

abstract class IDeriveMasterKey {
  Future<Uint8List> deriveKey(String masterPassword, VaultParameters parameters);
}