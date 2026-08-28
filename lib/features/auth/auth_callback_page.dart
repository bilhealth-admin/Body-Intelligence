import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/widgets/bil_wordmark.dart';
import 'auth_five_locale_copy.dart';

/// Completes a native OAuth callback without racing Supabase's PKCE exchange.
///
/// The OS can deliver `bil://auth-callback` to both GoRouter and
/// `supabase_flutter`. Navigation must therefore wait until Supabase has
/// persisted the resulting session instead of immediately returning to the
/// sign-in screen.
class AuthCallbackPage extends StatefulWidget {
  const AuthCallbackPage({super.key, this.initiallyFailed = false});

  final bool initiallyFailed;

  @override
  State<AuthCallbackPage> createState() => _AuthCallbackPageState();
}

class _AuthCallbackPageState extends State<AuthCallbackPage> {
  static const _timeout = Duration(seconds: 10);

  StreamSubscription<AuthState>? _subscription;
  Timer? _timer;
  bool _completed = false;
  late bool _failed;

  @override
  void initState() {
    super.initState();
    _failed = widget.initiallyFailed;
    if (!_failed) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_complete()),
      );
    }
  }

  @override
  void didUpdateWidget(covariant AuthCallbackPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.initiallyFailed && widget.initiallyFailed && !_completed) {
      _timer?.cancel();
      unawaited(_subscription?.cancel());
      // GoRouter can retain this State when only the callback query changes.
      // Update synchronously because a rebuild is already in progress.
      _failed = true;
    }
  }

  Future<void> _complete() async {
    if (!mounted || _completed) return;
    final auth = Supabase.instance.client.auth;

    if (auth.currentSession != null) {
      _finish();
      return;
    }

    _subscription = auth.onAuthStateChange.listen(
      (state) {
        if (state.session != null) _finish();
      },
      onError: (Object _, StackTrace _) {
        if (!mounted || _completed) return;
        setState(() => _failed = true);
      },
    );

    // Close the tiny race between the first synchronous check and installing
    // the auth-state listener. Any later PKCE completion is caught by the
    // listener above.
    await Future<void>.delayed(Duration.zero);
    if (auth.currentSession != null) {
      _finish();
      return;
    }

    _timer = Timer(_timeout, () {
      if (!mounted || _completed) return;
      setState(() => _failed = true);
    });
  }

  void _finish() {
    if (!mounted || _completed) return;
    _completed = true;
    _timer?.cancel();
    unawaited(_subscription?.cancel());
    context.go('/startup');
  }

  void _retry() {
    _timer?.cancel();
    unawaited(_subscription?.cancel());
    setState(() => _failed = false);
    unawaited(_complete());
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String tr(String en, String ar) => authFiveLocaleText(en, ar);

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BilWordmark(height: 48, color: Colors.white),
                  const SizedBox(height: 28),
                  if (!_failed) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(
                      tr(
                        'Finishing secure sign-in…',
                        'جارٍ إكمال تسجيل الدخول الآمن…',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 17),
                    ),
                  ] else ...[
                    const Icon(
                      Icons.lock_clock_outlined,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      tr(
                        'Secure sign-in did not finish in time. Your local data was not changed.',
                        'لم يكتمل تسجيل الدخول الآمن في الوقت المحدد. لم تتغير بياناتك المحلية.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(tr('Try again', 'حاول مرة أخرى')),
                    ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(
                        tr('Back to sign in', 'العودة لتسجيل الدخول'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
