import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/environment/app_environment.dart';
import '../../shared/widgets/bil_account_surface.dart';
import 'auth_language_selector.dart';
import 'supabase_auth_service.dart';
import 'auth_five_locale_copy.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key, required this.email});

  final String email;

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final code = TextEditingController();
  Timer? timer;
  int resendSeconds = 60;
  bool loading = false;
  String? status;

  bool get arabic => Localizations.localeOf(context).languageCode == 'ar';
  String tr(String en, String ar) => authFiveLocaleText(en, ar);

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    timer?.cancel();
    resendSeconds = 60;
    timer = Timer.periodic(const Duration(seconds: 1), (current) {
      if (!mounted) return;
      if (resendSeconds <= 1) {
        current.cancel();
        setState(() => resendSeconds = 0);
      } else {
        setState(() => resendSeconds--);
      }
    });
  }

  Future<void> verify() async {
    if (loading || code.text.length != 6 || widget.email.isEmpty) return;
    setState(() {
      loading = true;
      status = null;
    });
    try {
      await SupabaseAuthService(
        Supabase.instance.client,
      ).verifySignupCode(email: widget.email, code: code.text);
      if (mounted) context.go('/dashboard');
    } on AuthException {
      if (mounted) {
        setState(
          () => status =
              'The code could not be verified. Request a new code and try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => status = tr(
            'The code could not be verified.',
            'تعذر التحقق من الرمز.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> resend() async {
    if (resendSeconds > 0 || loading || widget.email.isEmpty) return;
    setState(() {
      loading = true;
      status = null;
    });
    try {
      await SupabaseAuthService(
        Supabase.instance.client,
      ).resendSignupCode(widget.email);
      if (mounted) {
        startTimer();
        setState(
          () => status = tr('A new code was sent.', 'تم إرسال رمز جديد.'),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => status = tr(
            'Wait, then try resending the code.',
            'انتظر قليلًا ثم حاول إعادة الإرسال.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final codeEnabled = AppEnvironment.emailOtpEnabled;
    final theme = Theme.of(context);
    return BilAccountSurface(
      title: codeEnabled
          ? tr('Verify email', 'تأكيد البريد')
          : tr('Check your email', 'افتح بريدك'),
      onBack: () => context.go('/login'),
      languageSelector: const AuthLanguageSelector(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.mark_email_read_outlined,
                      size: 54,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      codeEnabled
                          ? tr('Verify your email', 'تحقق من بريدك')
                          : tr('Check your email', 'افتح بريدك الإلكتروني'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: theme.colorScheme.onSurface),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      codeEnabled
                          ? tr(
                              'Enter the 6-digit code sent to ${widget.email}.',
                              'أدخل الرمز المكوّن من 6 أرقام المرسل إلى ${widget.email}.',
                            )
                          : tr(
                              'We sent a secure confirmation link to ${widget.email}. Open it to activate your account, then return to sign in.',
                              'أرسلنا رابط تأكيد آمنًا إلى ${widget.email}. افتحه لتفعيل حسابك، ثم عد لتسجيل الدخول.',
                            ),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (codeEnabled)
                      TextField(
                        key: const Key('email-verification-code'),
                        controller: code,
                        enabled: !loading,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 12,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '••••••',
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => verify(),
                      ),
                    if (status != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        status!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (codeEnabled)
                      FilledButton(
                        key: const Key('verify-email-submit'),
                        onPressed: code.text.length == 6 && !loading
                            ? verify
                            : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                        child: Text(tr('Verify account', 'تأكيد الحساب')),
                      )
                    else
                      FilledButton.icon(
                        key: const Key('email-link-return-to-login'),
                        onPressed: loading ? null : () => context.go('/login'),
                        icon: const Icon(Icons.login_rounded),
                        label: Text(
                          tr(
                            'I confirmed my email — sign in',
                            'أكدت بريدي — تسجيل الدخول',
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: resendSeconds == 0 && !loading ? resend : null,
                      child: Text(
                        resendSeconds == 0
                            ? tr('Resend code', 'إعادة إرسال الرمز')
                            : tr(
                                'Resend in $resendSeconds seconds',
                                'إعادة الإرسال خلال $resendSeconds ثانية',
                              ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(
                        tr('Back to sign in', 'العودة لتسجيل الدخول'),
                      ),
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
