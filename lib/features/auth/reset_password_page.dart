import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/environment/app_environment.dart';
import '../../shared/widgets/bil_wordmark.dart';
import 'auth_error_localizer.dart';
import 'auth_five_locale_copy.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    this.initiallyFailed = false,
    this.initiallyVerified = false,
    this.onRetry,
    this.recoverySessionEvents,
    this.recoveryTimeout = const Duration(seconds: 10),
    this.cloudConfiguredOverride,
  });

  final bool initiallyFailed;
  final bool initiallyVerified;
  final Future<bool> Function()? onRetry;
  final Stream<bool>? recoverySessionEvents;
  final Duration recoveryTimeout;
  final bool? cloudConfiguredOverride;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final formKey = GlobalKey<FormState>();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  StreamSubscription<bool>? authSubscription;
  Timer? recoveryTimer;
  bool recoverySessionReady = false;
  bool recoveryFailed = false;
  bool retryingRecovery = false;
  bool loading = false;
  bool obscure = true;
  String? status;

  @override
  void initState() {
    super.initState();
    recoverySessionReady = widget.initiallyVerified;
    recoveryFailed = widget.initiallyFailed && !recoverySessionReady;
    if (_cloudConfigured && !recoveryFailed && !recoverySessionReady) {
      _beginRecoveryWait();
    }
  }

  bool get _cloudConfigured =>
      widget.cloudConfiguredOverride ?? AppEnvironment.cloudConfigured;

  Stream<bool> _recoveryEvents() =>
      widget.recoverySessionEvents ??
      Supabase.instance.client.auth.onAuthStateChange.map(
        (state) =>
            state.event == AuthChangeEvent.passwordRecovery &&
            state.session != null,
      );

  void _beginRecoveryWait() {
    recoveryTimer?.cancel();
    unawaited(authSubscription?.cancel());
    authSubscription = _recoveryEvents().listen((ready) {
      if (!ready || !mounted) return;
      recoveryTimer?.cancel();
      setState(() {
        recoverySessionReady = true;
        recoveryFailed = false;
        retryingRecovery = false;
      });
    }, onError: (Object _, StackTrace _) => _showRecoveryFailure());
    recoveryTimer = Timer(widget.recoveryTimeout, _showRecoveryFailure);
  }

  void _showRecoveryFailure() {
    if (!mounted || recoverySessionReady) return;
    recoveryTimer?.cancel();
    unawaited(authSubscription?.cancel());
    authSubscription = null;
    setState(() {
      recoveryFailed = true;
      retryingRecovery = false;
    });
  }

  Future<void> _retryRecovery() async {
    if (retryingRecovery || recoverySessionReady) return;
    recoveryTimer?.cancel();
    await authSubscription?.cancel();
    authSubscription = null;
    if (!mounted) return;

    setState(() {
      recoveryFailed = false;
      retryingRecovery = true;
      status = null;
    });
    _beginRecoveryWait();

    var exchanged = false;
    try {
      exchanged = await widget.onRetry?.call() ?? false;
    } catch (_) {
      exchanged = false;
    }
    if (!mounted || recoverySessionReady) return;
    if (!exchanged) {
      _showRecoveryFailure();
    } else {
      setState(() => retryingRecovery = false);
    }
  }

  @override
  void didUpdateWidget(covariant ResetPasswordPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.initiallyVerified &&
        widget.initiallyVerified &&
        !recoverySessionReady) {
      recoveryTimer?.cancel();
      unawaited(authSubscription?.cancel());
      authSubscription = null;
      recoverySessionReady = true;
      recoveryFailed = false;
      retryingRecovery = false;
      return;
    }
    if (!oldWidget.initiallyFailed &&
        widget.initiallyFailed &&
        !recoverySessionReady) {
      recoveryTimer?.cancel();
      unawaited(authSubscription?.cancel());
      authSubscription = null;
      recoveryFailed = true;
      retryingRecovery = false;
    }
  }

  @override
  void dispose() {
    recoveryTimer?.cancel();
    unawaited(authSubscription?.cancel());
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> updatePassword() async {
    if (!AppEnvironment.cloudConfigured ||
        !recoverySessionReady ||
        formKey.currentState?.validate() != true) {
      return;
    }
    setState(() {
      loading = true;
      status = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password.text),
      );
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/login');
    } on AuthException catch (error) {
      if (mounted) setState(() => status = localizedAuthError(context, error));
    } catch (_) {
      if (mounted) {
        setState(
          () => status = authFiveLocaleText(
            'The password could not be updated. Request a new link.',
            'تعذّر تحديث كلمة المرور. اطلب رابطًا جديدًا.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String tr(String en, String ar) => authFiveLocaleText(en, ar);
    final cloudConfigured = _cloudConfigured;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: BilFullWordmark(height: 42)),
                    const SizedBox(height: 44),
                    Text(
                      tr('Set a new password', 'تعيين كلمة مرور جديدة'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      tr(
                        'Use at least 8 characters, then sign in with your new password.',
                        'استخدم 8 أحرف على الأقل، ثم سجّل الدخول بكلمة المرور الجديدة.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    if (!recoverySessionReady)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: !cloudConfigured
                            ? Text(
                                tr(
                                  'Cloud account recovery is not enabled in this build.',
                                  'استعادة الحساب السحابي غير مفعّلة في هذا الإصدار.',
                                ),
                                textAlign: TextAlign.center,
                              )
                            : recoveryFailed
                            ? Column(
                                key: const Key(
                                  'reset-password-callback-failed',
                                ),
                                children: [
                                  const Icon(
                                    Icons.link_off_rounded,
                                    color: Color(0xFFB42318),
                                    size: 36,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    tr(
                                      'The recovery link could not be verified. Try it again, or request a new link.',
                                      'تعذّر التحقق من رابط الاستعادة. حاول مرة أخرى أو اطلب رابطًا جديدًا.',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFFB42318),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  FilledButton.tonalIcon(
                                    key: const Key(
                                      'reset-password-callback-retry',
                                    ),
                                    onPressed: retryingRecovery
                                        ? null
                                        : _retryRecovery,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: Text(
                                      tr('Try again', 'حاول مرة أخرى'),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => context.go('/login'),
                                    child: Text(
                                      tr('Request a new link', 'طلب رابط جديد'),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      tr(
                                        'Checking the recovery link…',
                                        'جارٍ التحقق من رابط الاستعادة…',
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    TextFormField(
                      controller: password,
                      obscureText: obscure,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: tr('New password', 'كلمة المرور الجديدة'),
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => obscure = !obscure),
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => (value?.length ?? 0) >= 8
                          ? null
                          : tr(
                              'Use at least 8 characters.',
                              'استخدم 8 أحرف على الأقل.',
                            ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmation,
                      obscureText: obscure,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: tr('Confirm password', 'تأكيد كلمة المرور'),
                        prefixIcon: const Icon(Icons.verified_user_outlined),
                      ),
                      validator: (value) => value == password.text
                          ? null
                          : tr(
                              'Passwords do not match.',
                              'كلمتا المرور غير متطابقتين.',
                            ),
                      onFieldSubmitted: (_) => updatePassword(),
                    ),
                    if (status != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        status!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFB42318)),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: recoverySessionReady && !loading
                          ? updatePassword
                          : null,
                      child: loading
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(tr('Save password', 'حفظ كلمة المرور')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
