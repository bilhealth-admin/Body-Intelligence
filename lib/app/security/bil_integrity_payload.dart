import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Returns the request digest shared by Flutter and the protected Edge
/// Functions.
///
/// JSON text is deliberately not used as the canonical form: Dart and
/// JavaScript can serialize the same IEEE-754 number differently. Numbers are
/// encoded by their big-endian float64 bits, while strings and map keys are
/// UTF-8 length-prefixed. This keeps the grant bound to the exact semantic
/// request that the server receives.
String bilIntegrityPayloadDigest(Map<String, Object?> payload) =>
    sha256.convert(utf8.encode(bilIntegrityCanonicalValue(payload))).toString();

String bilIntegrityCanonicalValue(Object? value) {
  if (value == null) return 'N;';
  if (value is bool) return value ? 'B1;' : 'B0;';
  if (value is String) return _lengthPrefixed('S', value);
  if (value is num) {
    final number = value.toDouble();
    if (!number.isFinite) {
      throw const FormatException('integrity_payload_non_finite_number');
    }
    final bytes = ByteData(8)..setFloat64(0, number, Endian.big);
    final bits = List<int>.generate(
      8,
      bytes.getUint8,
      growable: false,
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return 'D$bits;';
  }
  if (value is List) {
    return 'L${value.length}:[${value.map(bilIntegrityCanonicalValue).join()}];';
  }
  if (value is Map) {
    final entries =
        value.entries
            .map((entry) {
              if (entry.key is! String) {
                throw const FormatException('integrity_payload_non_string_key');
              }
              return MapEntry(entry.key as String, entry.value);
            })
            .toList(growable: false)
          ..sort((left, right) => left.key.compareTo(right.key));
    final encoded = entries
        .map(
          (entry) =>
              '${_lengthPrefixed('K', entry.key)}${bilIntegrityCanonicalValue(entry.value)}',
        )
        .join();
    return 'M${entries.length}:{$encoded};';
  }
  throw FormatException(
    'integrity_payload_unsupported_type:${value.runtimeType}',
  );
}

String _lengthPrefixed(String tag, String value) =>
    '$tag${utf8.encode(value).length}:$value;';
