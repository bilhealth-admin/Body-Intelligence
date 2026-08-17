import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
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
  final phone = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  Country selectedCountry = Country.parse('EG');
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
            phone: AuthInputValidation.normalizeNationalPhone(
              phone.text,
              selectedCountry.phoneCode,
            ),
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
    phone.dispose();
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
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BilWordmark(height: 44)),
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
                    tr('Full name', 'الاسم الكامل'),
                    Icons.person_outline,
                  ),
                  const SizedBox(height: 12),
                  _phoneField(),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
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

  void _normalizeVisiblePhone(String value) {
    final normalized = AuthInputValidation.normalizeVisibleNationalPhone(
      value,
      selectedCountry.phoneCode,
    );
    if (normalized != value) {
      final removedCharacterCount = value.length - normalized.length;
      final currentOffset = phone.selection.extentOffset;
      final normalizedOffset = (currentOffset - removedCharacterCount)
          .clamp(0, normalized.length)
          .toInt();
      phone.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalizedOffset),
      );
    }
    setState(() {});
  }

  Widget _phoneField() => TextFormField(
    controller: phone,
    enabled: AppEnvironment.cloudConfigured && !loading,
    keyboardType: TextInputType.phone,
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.start,
    style: Theme.of(context).textTheme.bodyLarge,
    decoration:
        _decoration(
          tr('Phone number', 'رقم الهاتف'),
          Icons.phone_outlined,
        ).copyWith(
          prefixIconConstraints: const BoxConstraints(minWidth: 116),
          prefixIcon: InkWell(
            onTap: loading ? null : _selectCountry,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 14, end: 10),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedCountry.flagEmoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(width: 7),
                    Semantics(
                      label: '+${selectedCountry.phoneCode}',
                      child: ExcludeSemantics(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          textDirection: TextDirection.ltr,
                          children: [
                            const Text(
                              '+',
                              maxLines: 1,
                              softWrap: false,
                              textDirection: TextDirection.ltr,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              selectedCountry.phoneCode,
                              maxLines: 1,
                              softWrap: false,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(Icons.arrow_drop_down_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
    validator: (value) =>
        AuthInputValidation.isValidNationalPhone(
          value,
          selectedCountry.phoneCode,
        )
        ? null
        : tr(
            'Enter a valid phone number for the selected country.',
            'أدخل رقم هاتف صحيحًا للدولة المختارة.',
          ),
    onChanged: _normalizeVisiblePhone,
  );

  void _selectCountry() {
    showCountryPicker(
      context: context,
      useSafeArea: true,
      // The selected calling code remains visible beside the input. Hiding it
      // in the RTL country list avoids the package's long-code line break
      // where the plus sign was rendered alone on a second line.
      showPhoneCode: false,
      countryListTheme: CountryListThemeData(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        inputDecoration: InputDecoration(
          labelText: tr('Search country', 'ابحث عن الدولة'),
          prefixIcon: const Icon(Icons.search_rounded),
          border: const OutlineInputBorder(),
        ),
      ),
      onSelect: (country) {
        selectedCountry = country;
        _normalizeVisiblePhone(phone.text);
      },
    );
  }

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

  InputDecoration _decoration(String label, IconData icon) =>
      InputDecoration(labelText: label, prefixIcon: Icon(icon));
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
          child: LinearProgressIndicator(
            value: score / 3,
            minHeight: 4,
            color: color,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}
