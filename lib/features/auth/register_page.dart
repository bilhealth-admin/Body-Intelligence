import '../../shared/widgets/bil_pearl_feature_welcome.dart';
import '../../shared/widgets/bil_pearl_material.dart';
import '../../shared/widgets/bil_striped_progress.dart';
import '../../shared/widgets/bil_navigation_feedback.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/environment/app_environment.dart';
import '../../shared/widgets/bil_account_surface.dart';
import '../../shared/widgets/bil_wordmark.dart';
import 'auth_language_selector.dart';
import 'auth_error_localizer.dart';
import 'supabase_auth_service.dart';
import 'auth_input_validation.dart';
import 'auth_five_locale_copy.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool obscurePassword = true;
  bool obscureConfirmation = true;
  bool accepted = false;
  bool loading = false;
  String? status;

  bool get arabic => Localizations.localeOf(context).languageCode == 'ar';
  String tr(String en, String ar) => authFiveLocaleText(en, ar);

  Future<void> submit() async {
    if (loading || !accepted || formKey.currentState?.validate() != true) {
      return;
    }
    setState(() {
      loading = true;
      status = null;
    });
    try {
      final outcome = await SupabaseAuthService(Supabase.instance.client)
          .signUp(
            email: email.text.trim().toLowerCase(),
            password: password.text,
            fullName: name.text.trim(),
          );
      if (!mounted) return;
      if (outcome == BilAuthOutcome.confirmationRequired) {
        context.go('/verify-email', extra: email.text.trim().toLowerCase());
      } else {
        context.go('/startup');
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => status = localizedAuthError(context, error));
    } catch (_) {
      if (mounted) {
        setState(
          () => status = tr(
            'Account creation failed securely. Try again.',
            'تعذر إنشاء الحساب بأمان. حاول مرة أخرى.',
          ),
        );
      }
    } finally {
      if (mounted && loading) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configured = AppEnvironment.cloudConfigured;
    final theme = Theme.of(context);
    return BilAccountSurface(
      title: tr('Create account', 'إنشاء حساب'),
      onBack: () =>
          context.canPop() ? context.pop() : context.go('/account-gateway'),
      languageSelector: const AuthLanguageSelector(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: BilPearlMaterialCard(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BilFullWordmark(height: 44)),
                  Text(
                    tr('Create your private account', 'أنشئ حسابك الخاص'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      'Your health data remains under your control.',
                      'تبقى بياناتك الصحية تحت سيطرتك.',
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _field(
                    name,
                    tr('Display name (optional)', 'الاسم المعروض (اختياري)'),
                    Icons.person_outline,
                    validator: (_) => null,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    email,
                    tr('Email', 'البريد الإلكتروني'),
                    Icons.email_outlined,
                    keyboard: TextInputType.emailAddress,
                    validator: (value) =>
                        AuthInputValidation.isValidEmail(value)
                        ? null
                        : tr('Enter a valid email.', 'أدخل بريدًا صحيحًا.'),
                  ),
                  const SizedBox(height: 12),
                  _passwordField(
                    password,
                    tr('Password', 'كلمة المرور'),
                    obscurePassword,
                    () => setState(() => obscurePassword = !obscurePassword),
                    validator: (value) => _passwordError(value ?? ''),
                  ),
                  const SizedBox(height: 8),
                  _PasswordStrength(value: password.text, arabic: arabic),
                  const SizedBox(height: 12),
                  _passwordField(
                    confirmation,
                    tr('Confirm password', 'تأكيد كلمة المرور'),
                    obscureConfirmation,
                    () => setState(
                      () => obscureConfirmation = !obscureConfirmation,
                    ),
                    validator: (value) => value == password.text
                        ? null
                        : tr(
                            'Passwords do not match.',
                            'كلمتا المرور غير متطابقتين.',
                          ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: accepted,
                    onChanged: loading
                        ? null
                        : (value) => setState(() => accepted = value == true),
                    title: Text(
                      tr(
                        'I agree to the Terms and Privacy Policy.',
                        'أوافق على شروط الاستخدام وسياسة الخصوصية.',
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (status != null)
                    Text(
                      status!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('register-submit'),
                    onPressed: configured && accepted && !loading
                        ? submit
                        : null,
                    icon: loading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: BilFeatureWelcomeStatus(),
                          )
                        : const Icon(Icons.person_add_alt_1_rounded),
                    label: Text(tr('Create account', 'إنشاء الحساب')),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    enabled: AppEnvironment.cloudConfigured && !loading,
    keyboardType: keyboard,
    style: Theme.of(context).textTheme.bodyLarge,
    decoration: _decoration(label, icon),
    validator:
        validator ??
        (value) => (value?.trim().length ?? 0) >= 2
            ? null
            : tr('This field is required.', 'هذا الحقل مطلوب.'),
  );

  Widget _passwordField(
    TextEditingController controller,
    String label,
    bool obscure,
    VoidCallback toggle, {
    required String? Function(String?) validator,
  }) => TextFormField(
    controller: controller,
    enabled: AppEnvironment.cloudConfigured && !loading,
    obscureText: obscure,
    style: Theme.of(context).textTheme.bodyLarge,
    decoration: _decoration(label, Icons.lock_outline).copyWith(
      suffixIcon: IconButton(
        onPressed: toggle,
        icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
      ),
    ),
    validator: validator,
  );

  String? _passwordError(String value) {
    final strong =
        value.length >= 8 &&
        RegExp(r'[A-Za-z]').hasMatch(value) &&
        RegExp(r'[0-9]').hasMatch(value);
    return strong
        ? null
        : tr(
            'Use 8+ characters with letters and numbers.',
            'استخدم 8 أحرف أو أكثر تتضمن حروفًا وأرقامًا.',
          );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: BilNavigationFeedback(child: Icon(icon)),
  );
}

class _PasswordStrength extends StatelessWidget {
  const _PasswordStrength({required this.value, required this.arabic});

  final String value;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    var score = 0;
    if (value.length >= 8) score++;
    if (RegExp(r'[A-Za-z]').hasMatch(value)) score++;
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    final color = score < 2
        ? const Color(0xFFFF7A7A)
        : score == 2
        ? const Color(0xFFFFC857)
        : const Color(0xFF37D39A);
    final label = score < 2
        ? authFiveLocaleText('Weak', 'ضعيفة')
        : score == 2
        ? authFiveLocaleText('Good', 'جيدة')
        : authFiveLocaleText('Strong', 'قوية');
    return Row(
      children: [
        Expanded(
          child: BilStripedProgress(
            child: LinearProgressIndicator(
              value: score / 3,
              minHeight: 4,
              color: color,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}
