import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// System backup is distinct from BIL's explicitly consented encrypted sync.
/// No health files are opened until the native exclusion is verified.
final class BilHealthStoragePrivacy {
  BilHealthStoragePrivacy({bool? isIos, MethodChannel? channel})
    : _isIos = isIos ?? (!kIsWeb && Platform.isIOS),
      _channel = channel ?? const MethodChannel('bil/health_storage_privacy');

  static final instance = BilHealthStoragePrivacy();
  final bool _isIos;
  final MethodChannel _channel;
  Future<void>? _pending;

  bool get requiresProtection => _isIos;

  Future<void> ensureProtected() {
    if (!_isIos) return Future<void>.value();
    final pending = _pending;
    if (pending != null) return pending;
    late final Future<void> operation;
    operation = _verify().whenComplete(() {
      if (identical(_pending, operation)) _pending = null;
    });
    _pending = operation;
    return operation;
  }

  Future<void> _verify() async {
    final result = await _channel
        .invokeMapMethod<String, Object?>('protectHealthStorage')
        .timeout(const Duration(seconds: 8));
    if (result?['scopeVersion'] != 1 ||
        result?['applicationSupportExcluded'] != true ||
        result?['documentsExcluded'] != true ||
        result?['preferencesExcluded'] != true) {
      throw PlatformException(
        code: 'health_backup_exclusion_unverified',
        message: 'Health storage privacy could not be verified.',
      );
    }
  }
}
