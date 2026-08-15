import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/environment/app_environment.dart';
import '../../shared/widgets/bil_wordmark.dart';
import 'auth_language_selector.dart';
import 'supabase_auth_service.dart';
import 'auth_input_validation.dart';
import 'auth_error_localizer.dart';
import 'auth_five_locale_copy.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;
  bool loading = false;
  OAuthProvider? oauthLoading;
  String? status;

  String tr(String en, String ar) {
    final language = Localizations.localeOf(context).languageCode;
    if (language == 'ar') return ar;
    const translations = <String, Map<String, String>>{
      'Back': {'fr': 'Retour', 'es': 'Atrás', 'tr': 'Geri'},
      'Welcome back': {
        'fr': 'Bon retour',
        'es': 'Bienvenido de nuevo',
        'tr': 'Tekrar hoş geldiniz',
      },
      'Your private health intelligence is ready.': {
        'fr': 'Votre intelligence santé privée est prête.',
        'es': 'Tu inteligencia de salud privada está lista.',
        'tr': 'Özel sağlık zekânız hazır.',
      },
      'Email address': {
        'fr': 'Adresse e-mail',
        'es': 'Correo electrónico',
        'tr': 'E-posta adresi',
      },
      'Enter a valid email.': {
        'fr': 'Saisissez une adresse e-mail valide.',
        'es': 'Introduce un correo válido.',
        'tr': 'Geçerli bir e-posta girin.',
      },
      'Password': {'fr': 'Mot de passe', 'es': 'Contraseña', 'tr': 'Parola'},
      'Use at least 8 characters.': {
        'fr': 'Utilisez au moins 8 caractères.',
        'es': 'Usa al menos 8 caracteres.',
        'tr': 'En az 8 karakter kullanın.',
      },
      'Forgot password?': {
        'fr': 'Mot de passe oublié ?',
        'es': '¿Olvidaste tu contraseña?',
        'tr': 'Parolanızı mı unuttunuz?',
      },
      'Sign in securely': {
        'fr': 'Connexion sécurisée',
        'es': 'Iniciar sesión de forma segura',
        'tr': 'Güvenli giriş yap',
      },
      'Create a BIL account': {
        'fr': 'Créer un compte BIL',
        'es': 'Crear una cuenta BIL',
        'tr': 'BIL hesabı oluştur',
      },
      'Continue privately on this device': {
        'fr': 'Continuer en privé sur cet appareil',
        'es': 'Continuar de forma privada en este dispositivo',
        'tr': 'Bu cihazda gizli olarak devam et',
      },
      'Enter your email first.': {
        'fr': "Saisissez d’abord votre e-mail.",
        'es': 'Introduce primero tu correo.',
        'tr': 'Önce e-posta adresinizi girin.',
      },
      'Secure connection failed. Try again.': {
        'fr': 'La connexion sécurisée a échoué. Réessayez.',
        'es': 'Falló la conexión segura. Inténtalo de nuevo.',
        'tr': 'Güvenli bağlantı başarısız. Tekrar deneyin.',
      },
      'Could not send reset instructions. Try again.': {
        'fr': 'Impossible d’envoyer les instructions. Réessayez.',
        'es': 'No se pudieron enviar las instrucciones. Inténtalo de nuevo.',
        'tr': 'Sıfırlama talimatları gönderilemedi. Tekrar deneyin.',
      },
      'Password reset instructions were sent if this account exists.': {
        'fr': 'Les instructions ont été envoyées si ce compte existe.',
        'es': 'Se enviaron las instrucciones si la cuenta existe.',
        'tr': 'Hesap mevcutsa sıfırlama talimatları gönderildi.',
      },
      'Cloud account configuration is not enabled in this build.': {
        'fr': 'Le compte cloud n’est pas activé dans cette version.',
        'es': 'La cuenta en la nube no está activada en esta versión.',
        'tr': 'Bulut hesabı bu sürümde etkin değil.',
      },
    };
    return translations[en]?[language] ?? authFiveLocaleTextOf(context, en, ar);
  }

  Future<void> submitOAuth(OAuthProvider provider) async {
    if (loading || oauthLoading != null) return;
    if (!AppEnvironment.cloudConfigured) {
      setState(
        () => status = tr(
          'Cloud account configuration is not enabled in this build.',
          'إعداد الحساب السحابي غير مفعّل في هذا الإصدار.',
        ),
      );
      return;
    }
    setState(() {
      oauthLoading = provider;
      status = null;
    });
    try {
      final opened = await SupabaseAuthService(
        Supabase.instance.client,
      ).signInWithOAuth(provider);
      if (!opened && mounted) {
        setState(
          () => status = tr(
            'This sign-in provider is unavailable or not configured.',
            'مزود تسجيل الدخول هذا غير متاح أو غير مهيأ.',
          ),
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => status = localizedAuthError(context, error));
    } catch (_) {
      if (mounted) {
        setState(
          () => status = tr(
            'Could not open secure sign-in. Try again.',
            'تعذّر فتح تسجيل الدخول الآمن. حاول مرة أخرى.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => oauthLoading = null);
    }
  }

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
    } on AuthException catch (error) {
      if (mounted) setState(() => status = localizedAuthError(context, error));
    } catch (_) {
      if (mounted) {
        setState(
          () => status = tr(
            'Secure connection failed. Try again.',
            'تعذّر الاتصال الآمن. حاول مرة أخرى.',
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
            'تعذّر إرسال تعليمات الاستعادة. حاول مرة أخرى.',
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
      backgroundColor: const Color(0xFFF7F8FB),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFFF7F8FB)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(30, 20, 30, 30),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 410),
                  child: Form(
                    key: formKey,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const AuthLanguageSelector(),
                              const Spacer(),
                              IconButton(
                                tooltip: tr('Back', 'رجوع'),
                                onPressed: () => context.go('/account-gateway'),
                                icon: const Icon(Icons.arrow_back_rounded),
                                color: const Color(0xFF101828),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Center(child: BilWordmark(height: 50)),
                          const SizedBox(height: 32),
                          Text(
                            tr('Welcome back', 'مرحبًا بعودتك'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF101828),
                              fontSize: 29,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tr(
                              'Your private health intelligence is ready.',
                              'ذكاؤك الصحي الشخصي جاهز لمتابعة رحلتك.',
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFF667085),
                              fontSize: 15.5,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 30),
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
                            style: const TextStyle(color: Color(0xFF101828)),
                            decoration: _decoration(
                              tr('Email address', 'البريد الإلكتروني'),
                              Icons.mail_outline_rounded,
                            ),
                            validator: (value) =>
                                AuthInputValidation.isValidEmail(value)
                                ? null
                                : tr(
                                    'Enter a valid email.',
                                    'أدخل بريدًا إلكترونيًا صحيحًا.',
                                  ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            key: const Key('login-password'),
                            controller: password,
                            enabled: configured && !loading,
                            obscureText: obscure,
                            autofillHints: const [AutofillHints.password],
                            style: const TextStyle(color: Color(0xFF101828)),
                            decoration:
                                _decoration(
                                  tr('Password', 'كلمة المرور'),
                                  Icons.lock_outline_rounded,
                                ).copyWith(
                                  suffixIcon: IconButton(
                                    onPressed: configured
                                        ? () =>
                                              setState(() => obscure = !obscure)
                                        : null,
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
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: const Color(0x22FF7777),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                status!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFB42318),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            key: const Key('login-submit'),
                            onPressed: configured && !loading ? submit : null,
                            icon: loading
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward_rounded),
                            label: Text(
                              tr('Sign in securely', 'تسجيل الدخول الآمن'),
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(60),
                              backgroundColor: const Color(0xFF0066EE),
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Text(
                                  tr('OR', 'أو'),
                                  style: const TextStyle(
                                    color: Color(0xFF667085),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _oauthButton(
                            key: const Key('oauth-google'),
                            provider: OAuthProvider.google,
                            label: tr(
                              'Continue with Google',
                              'المتابعة باستخدام Google',
                            ),
                            brand: const Text(
                              'G',
                              style: TextStyle(
                                color: Color(0xFF4285F4),
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _oauthButton(
                            key: const Key('oauth-apple'),
                            provider: OAuthProvider.apple,
                            label: tr(
                              'Continue with Apple',
                              'المتابعة باستخدام Apple',
                            ),
                            brand: const Icon(Icons.apple, size: 27),
                          ),
                          const SizedBox(height: 10),
                          _oauthButton(
                            key: const Key('oauth-facebook'),
                            provider: OAuthProvider.facebook,
                            label: tr(
                              'Continue with Facebook',
                              'المتابعة باستخدام Facebook',
                            ),
                            brand: const Icon(
                              Icons.facebook,
                              color: Color(0xFF1877F2),
                              size: 27,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            tr(
                              'We will never post anything without your permission.',
                              'لن ننشر أي شيء دون إذنك.',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF667085),
                              fontSize: 13.5,
                            ),
                          ),
                          TextButton(
                            key: const Key('login-privacy-policy'),
                            onPressed: () => context.push('/legal/privacy'),
                            child: Text(
                              tr(
                                'Read the Privacy Policy',
                                'اقرأ سياسة الخصوصية',
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
                              minimumSize: const Size.fromHeight(56),
                              foregroundColor: const Color(0xFF0066EE),
                              side: const BorderSide(color: Color(0xFF0066EE)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(
                              tr('Create a BIL account', 'إنشاء حساب BIL'),
                            ),
                          ),
                          const SizedBox(height: 11),
                          TextButton.icon(
                            onPressed: () => context.go('/dashboard'),
                            icon: const Icon(Icons.shield_outlined, size: 19),
                            label: Text(
                              tr(
                                'Continue privately on this device',
                                'المتابعة بخصوصية على هذا الجهاز',
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF475467),
                            ),
                          ),
                          if (!configured)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                tr(
                                  'Cloud account configuration is not enabled in this build.',
                                  'الحساب السحابي غير مفعّل في هذه النسخة.',
                                ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF667085),
                                ),
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
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFF0066EE), width: 1.5),
    ),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
  );

  Widget _oauthButton({
    required Key key,
    required OAuthProvider provider,
    required String label,
    required Widget brand,
  }) {
    final busy = oauthLoading == provider;
    return OutlinedButton.icon(
      key: key,
      onPressed: !loading && oauthLoading == null
          ? () => submitOAuth(provider)
          : null,
      icon: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : SizedBox(width: 28, child: Center(child: brand)),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        foregroundColor: const Color(0xFF101828),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFD0D5DD)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
