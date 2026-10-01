import 'package:flutter_test/flutter_test.dart';

import '../tool/epic12_security_audit.dart' as security_audit;

void main() {
  test('archive checksum verify flags are not classified as TLS bypasses', () {
    for (final source in const <String>[
      'Uint8List decodeBytes(List<int> data, {bool verify = false})',
      'bool decodeStream(InputStream input, {bool verify = false})',
      'decodeStream(input, output, verify: verify);',
    ]) {
      expect(security_audit.hasTlsVerificationBypass(source), isFalse);
    }
  });

  test('known TLS verification bypass patterns remain blocked', () {
    for (final source in const <String>[
      'client.badCertificate'
          'Callback = (cert, host, port) => true;',
      'context.verify_mode = ssl.CERT_'
          'NONE;',
      'const agent = new https.Agent({reject'
          'Unauthorized: false});',
      'NODE_TLS_REJECT_'
          'UNAUTHORIZED=0',
      'ssl._create_'
          'unverified_context()',
      'context.check_'
          'hostname = false;',
      'curl_setopt(handle, CURLOPT_SSL_'
          'VERIFYPEER, 0);',
      'requests.get(url, veri'
          'fy=false)',
      'httpx.Client(veri'
          'fy=false)',
    ]) {
      expect(
        security_audit.hasTlsVerificationBypass(source),
        isTrue,
        reason: source,
      );
    }
  });
}
