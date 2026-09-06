import 'package:flutter/material.dart';

/// Redacts health content while the app is backgrounded or represented in the
/// operating-system task switcher. The shield contains no user data.
///
/// `inactive` is intentionally not redacted: iOS emits that transient state
/// while presenting camera, microphone, HealthKit, and photo-picker consent
/// sheets. Covering the Flutter surface at that moment makes those native
/// flows look like a frozen dark screen and can race camera/audio teardown.
/// The OS-facing `hidden`/`paused` states still receive the privacy shield.
class AppSwitcherPrivacyShield extends StatefulWidget {
  const AppSwitcherPrivacyShield({required this.child, super.key});

  final Widget child;

  @override
  State<AppSwitcherPrivacyShield> createState() =>
      _AppSwitcherPrivacyShieldState();
}

class _AppSwitcherPrivacyShieldState extends State<AppSwitcherPrivacyShield>
    with WidgetsBindingObserver {
  bool _redacted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final redact = switch (state) {
      AppLifecycleState.resumed || AppLifecycleState.inactive => false,
      AppLifecycleState.hidden ||
      AppLifecycleState.paused ||
      AppLifecycleState.detached => true,
    };
    if (redact != _redacted && mounted) setState(() => _redacted = redact);
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      widget.child,
      if (_redacted)
        const ColoredBox(
          key: Key('app-switcher-privacy-shield'),
          color: Color(0xFF07131E),
          child: Center(
            child: ExcludeSemantics(
              child: Icon(
                Icons.health_and_safety_outlined,
                color: Colors.white,
              ),
            ),
          ),
        ),
    ],
  );
}
