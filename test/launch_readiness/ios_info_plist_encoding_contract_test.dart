import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS Health usage text is valid UTF-8 without mojibake', () {
    final bytes = File('ios/Runner/Info.plist').readAsBytesSync();
    final plist = utf8.decode(bytes, allowMalformed: false);

    expect(plist, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
    expect(plist, contains('<key>NSHealthShareUsageDescription</key>'));
    expect(plist, contains('categories you choose—activity'));
    expect(plist, isNot(contains('â€”')));
    expect(plist, isNot(contains('\uFFFD')));
    expect(RegExp(r'<plist\b[^>]*>').allMatches(plist), hasLength(1));
    expect(RegExp(r'</plist>').allMatches(plist), hasLength(1));
    expect(
      RegExp(r'<dict>').allMatches(plist).length,
      RegExp(r'</dict>').allMatches(plist).length,
    );
  });
}
