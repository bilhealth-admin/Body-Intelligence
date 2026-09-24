import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('website callback fallback strips credentials and renders none', () {
    final source = File('public_site/app.js').readAsStringSync();
    final start = source.indexOf('function renderAuthCallbackFallback');
    final end = source.indexOf('function updateDocumentMetadata', start);
    final fallback = source.substring(start, end);

    expect(source, contains("path === '/auth/callback'"));
    expect(
      fallback,
      contains("history.replaceState(null, '', '/auth/callback')"),
    );
    expect(fallback, isNot(contains('location.search')));
    expect(fallback, isNot(contains('location.hash')));
    expect(fallback, isNot(contains('access_token')));
    expect(fallback, isNot(contains('code=')));
  });
}
