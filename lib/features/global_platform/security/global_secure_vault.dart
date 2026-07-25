import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

abstract interface class GlobalSecureVault {
  Future<void> write(String key, Uint8List value);
  Future<Uint8List?> read(String key);
  Future<void> delete(String key);
}

final class MemoryGlobalSecureVault implements GlobalSecureVault {
  final Map<String, Uint8List> _values = {};
  @override
  Future<void> write(String key, Uint8List value) async =>
      _values[key] = Uint8List.fromList(value);
  @override
  Future<Uint8List?> read(String key) async {
    final value = _values[key];
    return value == null ? null : Uint8List.fromList(value);
  }

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

String secureFingerprint(String namespace, List<int> payload) =>
    sha256.convert(<int>[...utf8.encode(namespace), 0, ...payload]).toString();
