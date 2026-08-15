import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/environment/app_environment.dart';
import '../../shared/widgets/bil_wordmark.dart';
import '../startup/premium_splash_experience.dart';
import 'auth_language_selector.dart';
import 'supabase_auth_service.dart';
import 'auth_input_validation.dart';
import 'auth_error_localizer.dart';
import 'auth_five_locale_copy.dart';
export 'premium_login_page.dart' show LoginPage;

class LegacyLoginPage extends StatefulWidget {
  const LegacyLoginPage({super.key});

  @override
  State<LegacyLoginPage> createState() => _LegacyLoginPageState();
}

class _LegacyLoginPageState extends State<LegacyLoginPage> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;
  bool loading = false;
  String? status;

  bool get arabic => Localizations.localeOf(context).languageCode == 'ar';
  String tr(String en, String ar) => authFiveLocaleText(en, ar);

  Future<void> submit() async {
    if (loading || !AppEnvironment.cloudConfigured) return;
    if (formKey.currentState?.validate() != true) return;
    setState(() {
      loading = true;
      status = null;
    });
    try {
      await SupabaseAuthService(
        Supabase.instance.client,
      ).signIn(email: email.text.trim().toLowerCase(), password: password.text);
      if (mounted) context.go('/dashboard');
    } on AuthException {
      if (mounted) {
        setState(
          () => status =
              'Sign-in could not be completed. Check your details and try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => status = tr(
            'Secure connection failed. Try again.',
            'تعذر الاتصال الآمن. حاول مرة أخرى.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> resetPassword() async {
    final normalized = email.text.trim().toLowerCase();
    if (!AuthInputValidation.isValidEmail(normalized)) {
      setState(
        () => status = tr(
          'Enter your email first.',
          'أدخل بريدك الإلكتروني أولًا.',
        ),
      );
      return;
    }
    setState(() {
      loading = true;
      status = null;
    });
    try {
      await SupabaseAuthService(
        Supabase.instance.client,
      ).sendPasswordReset(normalized);
      if (mounted) {
        setState(
          () => status = tr(
            'Password reset instructions were sent if this account exists.',
            'أُرسلت تعليمات استعادة كلمة المرور إذا كان الحساب موجودًا.',
          ),
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => status = localizedAuthError(context, error));
    } catch (_) {
      if (mounted) {
        setState(
          () => status = tr(
            'Could not send reset instructions. Try again.',
            'تعذر إرسال تعليمات الاستعادة. حاول مرة أخرى.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configured = AppEnvironment.cloudConfigured;
    return Scaffold(
      backgroundColor: const Color(0xFF01050D),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PremiumSplashBackdrop(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Card(
                    color: const Color(0xE80A1827),
                    elevation: 18,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                      side: const BorderSide(color: Color(0x335FDDF4)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(26, 24, 26, 28),
                      child: Form(
                        key: formKey,
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: AuthLanguageSelector(),
                              ),
                              const SizedBox(height: 16),
                              const Center(child: BilWordmark(height: 48)),
                              const SizedBox(height: 12),
                              Text(
                                tr('Welcome back', 'مرحبًا بعودتك'),
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                tr(
                                  'Continue your private body intelligence journey.',
                                  'تابع رحلة ذكاء جسمك بخصوصية وأمان.',
                                ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFB9C8D3),
                                ),
                              ),
                              const SizedBox(height: 26),
                              TextFormField(
                                key: const Key('login-email'),
                                controller: email,
                                enabled: configured && !loading,
                                keyboardType: TextInputType.emailAddress,
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.start,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                enableSuggestions: false,
                                autofillHints: const [AutofillHints.email],
                                onFieldSubmitted: (_) =>
                                    FocusScope.of(context).nextFocus(),
                                style: const TextStyle(color: Colors.white),
                                decoration: _decoration(
                                  tr('Email', 'البريد الإلكتروني'),
                                  Icons.email_outlined,
                                ),
                                validator: (value) =>
                                    AuthInputValidation.isValidEmail(value)
                                    ? null
                                    : tr(
                                        'Enter a valid email.',
                                        'أدخل بريدًا صحيحًا.',
                                      ),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                key: const Key('login-password'),
                                controller: password,
                                enabled: configured && !loading,
                                obscureText: obscure,
                                autofillHints: const [AutofillHints.password],
                                style: const TextStyle(color: Colors.white),
                                decoration:
                                    _decoration(
                                      tr('Password', 'كلمة المرور'),
                                      Icons.lock_outline_rounded,
                                    ).copyWith(
                                      suffixIcon: IconButton(
                                        onPressed: configured
                                            ? () => setState(
                                                () => obscure = !obscure,
                                              )
                                            : null,
                                        icon: Icon(
                                          obscure
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                        ),
                                      ),
                                    ),
                                validator: (value) => (value?.length ?? 0) >= 8
                                    ? null
                                    : tr(
                                        'Use at least 8 characters.',
                                        'استخدم 8 أحرف على الأقل.',
                                      ),
                                onFieldSubmitted: (_) => submit(),
                              ),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: TextButton(
                                  key: const Key('forgot-password'),
                                  onPressed: configured && !loading
                                      ? resetPassword
                                      : null,
                                  child: Text(
                                    tr('Forgot password?', 'نسيت كلمة المرور؟'),
                                  ),
                                ),
                              ),
                              if (status != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  status!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFFF9E9E),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 22),
                              FilledButton.icon(
                                key: const Key('login-submit'),
                                onPressed: configured && !loading
                                    ? submit
                                    : null,
                                icon: loading
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.arrow_forward_rounded),
                                label: Text(tr('Sign in', 'تسجيل الدخول')),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(56),
                                  backgroundColor: const Color(0xFF0BB7D1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                key: const Key('open-register'),
                                onPressed: configured && !loading
                                    ? () => context.push('/register')
                                    : null,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(54),
                                ),
                                child: Text(
                                  tr('Create a new account', 'إنشاء حساب جديد'),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextButton.icon(
                                onPressed: () => context.go('/dashboard'),
                                icon: const Icon(Icons.shield_outlined),
                                label: Text(
                                  tr(
                                    'Continue privately on this device',
                                    'المتابعة بخصوصية على هذا الجهاز',
                                  ),
                                ),
                              ),
                              if (!configured)
                                Text(
                                  tr(
                                    'Cloud account configuration is not enabled in this build.',
                                    'إعداد الحساب السحابي غير مفعّل في هذه النسخة.',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFB9C8D3),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: const Color(0xFF102337),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
  );
}
