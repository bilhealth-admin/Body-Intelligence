import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/environment/app_environment.dart';
import '../../shared/widgets/bil_account_surface.dart';
import 'auth_language_selector.dart';
import 'auth_error_localizer.dart';
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
      if (mounted) context.go('/startup');
    } on AuthException catch (error) {
      if (mounted) setState(() => status = localizedAuthError(context, error));
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
          () => status = tr(
            'If this email is awaiting verification, a new verification message was requested.',
            'إذا كان هذا البريد بانتظار التحقق، فقد تم طلب رسالة تحقق جديدة.',
          ),
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => status = localizedAuthError(context, error));
    } catch (_) {
      if (mounted) {
        setState(
          () => status = tr(
            'Wait, then try resending the verification message.',
            'انتظر قليلًا ثم حاول إعادة إرسال رسالة التحقق.',
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
                              'If this is a new account, enter the 6-digit verification code for ${widget.email}. If you already have a BIL account with this email, return to sign in instead.',
                              'إذا كان هذا حسابًا جديدًا، فأدخل رمز التحقق المكوّن من 6 أرقام للبريد ${widget.email}. وإذا كان لديك حساب BIL بهذا البريد بالفعل، فعد إلى تسجيل الدخول.',
                            )
                          : tr(
                              'If this is a new account, a secure confirmation link was requested for ${widget.email}. Open it to activate the account. If you already registered this email, return to sign in instead.',
                              'إذا كان هذا حسابًا جديدًا، فقد تم طلب رابط تأكيد آمن للبريد ${widget.email}. افتحه لتفعيل الحساب. وإذا كنت قد سجلت هذا البريد سابقًا، فعد إلى تسجيل الدخول بدلًا من ذلك.',
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
