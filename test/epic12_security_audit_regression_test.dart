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
      'client.badCertificateCallback = (cert, host, port) => true;',
      'context.verify_mode = ssl.CERT_NONE;',
      'const agent = new https.Agent({rejectUnauthorized: false});',
      'NODE_TLS_REJECT_UNAUTHORIZED=0',
      'ssl._create_unverified_context()',
      'context.check_hostname = false;',
      'curl_setopt(handle, CURLOPT_SSL_VERIFYPEER, 0);',
      'requests.get(url, verify=false)',
      'httpx.Client(verify=false)',
    ]) {
      expect(
        security_audit.hasTlsVerificationBypass(source),
        isTrue,
        reason: source,
      );
    }
  });
}
