import 'dart:convert';

import 'package:body_intelligence_log/app/localization/runtime_copy.dart';

/// Emits the canonical English runtime-copy keys for deterministic translation
/// tooling. The English sentence is the stable key at legacy call sites.
void main() {
  print(jsonEncode(RuntimeCopy.values.keys.toList(growable: false)));
}
// ignore_for_file: avoid_print
