import 'package:flutter/material.dart';

const bilResumeStartupThreshold = Duration(minutes: 30);

/// Returns whether a foreground re-entry should use the normal startup route.
///
/// A cold process already starts at `/startup`; this covers the equally common
/// case where iOS/Android kept the Flutter process alive while the app was
/// hidden for a long time. Authentication and native callback routes are
/// deliberately excluded so a pending sign-in/consent flow is never replaced.
@visibleForTesting
bool shouldReturnToStartupAfterBackground({
  required DateTime? backgroundedAt,
  required DateTime resumedAt,
  required String currentPath,
  Duration threshold = bilResumeStartupThreshold,
}) {
  if (backgroundedAt == null ||
      resumedAt.difference(backgroundedAt) < threshold ||
      currentPath.isEmpty ||
      currentPath == '/startup' ||
      currentPath == '/login' ||
      currentPath == '/reviewer-login' ||
      currentPath == '/auth-callback' ||
      currentPath == '/reset-password' ||
      currentPath.startsWith('/auth/')) {
    return false;
  }
  return true;
}

/// Redacts health content while the app is backgrounded or represented in the
/// operating-system task switcher. The shield contains no user data.
///
/// `inactive` is intentionally not redacted: iOS emits that transient state
/// while presenting camera, microphone, HealthKit, and photo-picker consent
/// sheets. Covering the Flutter surface at that moment makes those native
/// flows look like a frozen dark screen and can race camera/audio teardown.
/// The OS-facing `hidden`/`paused` states still receive the privacy shield.
class AppSwitcherPrivacyShield extends StatefulWidget {
  const AppSwitcherPrivacyShield({
    required this.child,
    this.currentPath,
    this.onLongBackgroundResume,
    this.resumeStartupThreshold = bilResumeStartupThreshold,
    super.key,
  });

  final Widget child;

  /// Reads the active route only when the app resumes after a long background.
  final String Function()? currentPath;

  /// The app shell supplies navigation to `/startup`. Keeping this callback
  /// optional preserves the privacy widget's isolated/testable behavior.
  final VoidCallback? onLongBackgroundResume;

  @visibleForTesting
  final Duration resumeStartupThreshold;

  @override
  State<AppSwitcherPrivacyShield> createState() =>
      _AppSwitcherPrivacyShieldState();
}

class _AppSwitcherPrivacyShieldState extends State<AppSwitcherPrivacyShield>
    with WidgetsBindingObserver {
  bool _redacted = false;
  DateTime? _backgroundedAt;
  bool _startupResumeRequested = false;

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
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _backgroundedAt ??= DateTime.now();
      _startupResumeRequested = false;
    }
    if (state == AppLifecycleState.resumed) {
      final backgroundedAt = _backgroundedAt;
      _backgroundedAt = null;
      final currentPath = widget.currentPath?.call() ?? '';
      if (!_startupResumeRequested &&
          shouldReturnToStartupAfterBackground(
            backgroundedAt: backgroundedAt,
            resumedAt: DateTime.now(),
            currentPath: currentPath,
            threshold: widget.resumeStartupThreshold,
          )) {
        _startupResumeRequested = true;
        final navigate = widget.onLongBackgroundResume;
        if (navigate != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) navigate();
          });
        }
      }
    }
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
