import 'dart:convert';

import 'package:flutter/foundation.dart';

enum AppLogLevel { info, warning, error }

abstract interface class AppLogger {
  void record(
    AppLogLevel level,
    String event, {
    Map<String, Object?> attributes = const {},
  });
}

class PrivacySafeLogger implements AppLogger {
  PrivacySafeLogger({void Function(String line)? sink}) : _sink = sink ?? print;
  final void Function(String line) _sink;
  static const _sensitiveKeys = {
    'email',
    'name',
    'token',
    'password',
    'weight',
    'food',
    'notes',
  };

  @override
  void record(
    AppLogLevel level,
    String event, {
    Map<String, Object?> attributes = const {},
  }) {
    final safe = <String, Object?>{};
    for (final entry in attributes.entries) {
      safe[entry.key] =
          _sensitiveKeys.any((key) => entry.key.toLowerCase().contains(key))
          ? '[redacted]'
          : entry.value;
    }
    _sink(jsonEncode({'level': level.name, 'event': event, ...safe}));
  }
}

abstract interface class ProductAnalytics {
  bool get uploadsData;
  void record(String event);
}

class DisabledProductAnalytics implements ProductAnalytics {
  const DisabledProductAnalytics();
  @override
  bool get uploadsData => false;
  @override
  void record(String event) {}
}

abstract interface class CrashReporter {
  bool get uploadsData;
  void record(Object error, StackTrace stackTrace);
}

class LocalOnlyCrashReporter implements CrashReporter {
  LocalOnlyCrashReporter(this.logger);
  final AppLogger logger;
  @override
  bool get uploadsData => false;
  @override
  void record(Object error, StackTrace stackTrace) {
    assert(() {
      debugPrint('BIL_DEBUG_UNCAUGHT: $error\n$stackTrace');
      return true;
    }());
    logger.record(
      AppLogLevel.error,
      'uncaught_error',
      attributes: {'errorType': error.runtimeType.toString()},
    );
  }
}

class AppObservability {
  AppObservability._();
  static final logger = PrivacySafeLogger();
  static const analytics = DisabledProductAnalytics();
  static final crashes = LocalOnlyCrashReporter(logger);
}
