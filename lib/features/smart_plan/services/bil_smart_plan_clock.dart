import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A civil-day clock shared by the view, tests, and explicit plan actions.
/// Diary writes still retain their selected date; midnight never logs a day.
final bilSmartPlanClockProvider = Provider<DateTime Function()>(
  (_) => DateTime.now,
);
