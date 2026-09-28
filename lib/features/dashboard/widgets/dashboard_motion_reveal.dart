import 'package:flutter/material.dart';

/// Keeps the composed Dashboard mounted without a cold-start opacity swap.
///
/// The old entrance started at zero opacity. That was visible as a one-frame
/// flash when StartupPage atomically handed off to Dashboard on a cold launch,
/// while later visits appeared stable because this state remained mounted.
/// Dashboard data already has truthful loading surfaces, so a second visual
/// reveal adds no information and must not hide the first usable frame.
class DashboardMotionReveal extends StatelessWidget {
  const DashboardMotionReveal({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
