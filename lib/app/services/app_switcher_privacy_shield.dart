import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Redacts health content while the app is backgrounded or represented in the
/// operating-system task switcher. The shield contains no user data.
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
    final mobilePlatform =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final redact = switch (state) {
      AppLifecycleState.resumed => false,
      AppLifecycleState.inactive => mobilePlatform,
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
