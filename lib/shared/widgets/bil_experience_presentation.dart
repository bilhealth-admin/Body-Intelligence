import 'package:flutter/foundation.dart';

/// One short presentation at a time. Financial/food transactions never wait
/// for this lease: callers leave their durable event pending when it is busy.
abstract final class BilExperiencePresentation {
  static final occupied = ValueNotifier<bool>(false);
  static Object? _token;
  static VoidCallback? tryClaim() {
    if (_token != null) return null;
    final token = Object();
    _token = token;
    occupied.value = true;
    var released = false;
    return () {
      if (released || !identical(_token, token)) return;
      released = true;
      _token = null;
      occupied.value = false;
    };
  }
}
