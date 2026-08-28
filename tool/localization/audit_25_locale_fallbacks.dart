import 'dart:convert';
import 'dart:io';

import 'locale_fallback_closure.dart';

Future<void> main() async {
  final result = await auditLocaleFallbackClosure();
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(result.toJson()));
  if (!result.passed) exitCode = 1;
}
