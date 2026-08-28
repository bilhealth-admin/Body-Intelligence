import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/environment/app_environment.dart';
import '../../shared/widgets/bil_wordmark.dart';
import '../startup/premium_splash_experience.dart';
import 'auth_entry_locale_copy.dart';
import 'auth_language_selector.dart';
import 'auth_five_locale_copy.dart';
import 'auth_input_validation.dart';
import 'supabase_auth_service.dart';
export 'premium_login_page.dart' show LoginPage;

class StoreReviewerLoginPage extends StatefulWidget {
  const StoreReviewerLoginPage({super.key});

  static const reviewerEmail = 'play-review@bilhealth.com';

  static bool acceptsReviewerEmail(String value) =>
      value.trim().toLowerCase() == reviewerEmail;

  @override
  State<StoreReviewerLoginPage> createState() => _StoreReviewerLoginPageState();
}

class _StoreReviewerLoginPageState extends State<StoreReviewerLoginPage> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;
  bool loading = false;
  String? status;

  String tr(String en, String ar) => authFiveLocaleTextOf(context, en, ar);

  Future<void> submit() async {
    if (loading || !AppEnvironment.cloudConfigured) return;
    if (formKey.currentState?.validate() != true) return;
    final normalized = email.text.trim().toLowerCase();
    if (!StoreReviewerLoginPage.acceptsReviewerEmail(normalized)) return;
    setState(() {
      loading = true;
      status = null;
    });
    try {
      await SupabaseAuthService(
        Supabase.instance.client,
      ).signIn(email: normalized, password: password.text);
      if (mounted) context.go('/startup');
    } on AuthException {
      if (mounted) {
        setState(
          () => status = authEntryText(
            context,
            AuthEntryCopyKey.authenticationFailed,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => status = authEntryText(
            context,
            AuthEntryCopyKey.secureConnectionFailure,
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
                              Row(
                                children: [
                                  IconButton(
                                    key: const Key('reviewer-login-back'),
                                    tooltip: authEntryText(
                                      context,
                                      AuthEntryCopyKey.back,
                                    ),
                                    onPressed: () => context.go('/login'),
                                    icon: const Icon(
                                      Icons.arrow_back_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Spacer(),
                                  const AuthLanguageSelector(),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Center(child: BilWordmark(height: 48)),
                              const SizedBox(height: 12),
                              Text(
                                tr(
                                  'Store reviewer access',
                                  'دخول مراجع المتجر',
                                ),
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
                                  'Use only the dedicated credentials supplied in the store review notes.',
                                  'استخدم فقط بيانات المراجع المخصصة والموجودة في ملاحظات مراجعة المتجر.',
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
                                  authEntryText(
                                    context,
                                    AuthEntryCopyKey.emailAddress,
                                  ),
                                  Icons.email_outlined,
                                ),
                                validator: (value) {
                                  if (!AuthInputValidation.isValidEmail(
                                    value,
                                  )) {
                                    return authEntryText(
                                      context,
                                      AuthEntryCopyKey.invalidEmail,
                                    );
                                  }
                                  if (!StoreReviewerLoginPage.acceptsReviewerEmail(
                                    value!,
                                  )) {
                                    return tr(
                                      'Use only the dedicated credentials supplied in the store review notes.',
                                      'استخدم فقط بيانات المراجع المخصصة والموجودة في ملاحظات مراجعة المتجر.',
                                    );
                                  }
                                  return null;
                                },
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
                                        'Use only the dedicated credentials supplied in the store review notes.',
                                        'استخدم فقط بيانات المراجع المخصصة والموجودة في ملاحظات مراجعة المتجر.',
                                      ),
                                onFieldSubmitted: (_) => submit(),
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
                                label: Text(
                                  authEntryText(
                                    context,
                                    AuthEntryCopyKey.signIn,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(56),
                                  backgroundColor: const Color(0xFF0BB7D1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                              if (!configured)
                                Text(
                                  authEntryText(
                                    context,
                                    AuthEntryCopyKey.cloudNotEnabled,
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
