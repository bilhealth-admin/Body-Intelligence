import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/environment/app_environment.dart';
import '../../shared/widgets/bil_wordmark.dart';
import 'auth_entry_locale_copy.dart';
import 'auth_error_localizer.dart';
import 'auth_five_locale_copy.dart';
import 'auth_input_validation.dart';
import 'supabase_auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  bool loading = false;
  OAuthProvider? oauthLoading;
  String? status;

  Future<void> submitEmail() async {
    if (loading || oauthLoading != null || !AppEnvironment.cloudConfigured) {
      return;
    }
    if (formKey.currentState?.validate() != true) return;
    final normalized = email.text.trim().toLowerCase();
    setState(() {
      loading = true;
      status = null;
    });
    try {
      await SupabaseAuthService(
        Supabase.instance.client,
      ).sendEmailOtp(normalized);
      if (mounted) context.push('/verify-email', extra: normalized);
    } on AuthException catch (error) {
      if (mounted) setState(() => status = localizedAuthError(context, error));
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

  Future<void> submitOAuth(OAuthProvider provider) async {
    if (loading || oauthLoading != null) return;
    if (!AppEnvironment.cloudConfigured) {
      setState(
        () => status = authEntryText(context, AuthEntryCopyKey.cloudNotEnabled),
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
          () => status = authEntryText(
            context,
            AuthEntryCopyKey.providerUnavailable,
          ),
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => status = localizedAuthError(context, error));
    } catch (_) {
      if (mounted) {
        setState(
          () => status = authEntryText(
            context,
            AuthEntryCopyKey.openSecureFailure,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => oauthLoading = null);
    }
  }

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configured = AppEnvironment.cloudConfigured;
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final pageBackground = dark ? scheme.surface : Colors.white;
    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            _AuthTopBar(
              title: authEntryText(context, AuthEntryCopyKey.signIn),
              backKey: const Key('login-back'),
              onBack: () => context.go('/account-gateway'),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 610;
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      constraints.maxWidth < 390 ? 22 : 28,
                      compact ? 24 : 34,
                      constraints.maxWidth < 390 ? 22 : 28,
                      24 + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Form(
                          key: formKey,
                          child: AutofillGroup(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const BilFullWordmark(
                                  key: Key('login-wordmark'),
                                  height: 38,
                                  alignment: Alignment.center,
                                ),
                                SizedBox(height: compact ? 18 : 24),
                                Text(
                                  authEntryText(
                                    context,
                                    AuthEntryCopyKey.emailAddress,
                                  ),
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  key: const Key('login-email'),
                                  controller: email,
                                  enabled:
                                      configured &&
                                      !loading &&
                                      oauthLoading == null,
                                  keyboardType: TextInputType.emailAddress,
                                  textDirection: TextDirection.ltr,
                                  textInputAction: TextInputAction.done,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  autofillHints: const [AutofillHints.email],
                                  style: TextStyle(
                                    color: scheme.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: _emailDecoration(context),
                                  validator: (value) =>
                                      AuthInputValidation.isValidEmail(value)
                                      ? null
                                      : authEntryText(
                                          context,
                                          AuthEntryCopyKey.invalidEmail,
                                        ),
                                  onFieldSubmitted: (_) => submitEmail(),
                                ),
                                if (status != null) ...[
                                  const SizedBox(height: 12),
                                  _StatusPanel(message: status!),
                                ],
                                const SizedBox(height: 18),
                                FilledButton(
                                  key: const Key('login-submit'),
                                  onPressed:
                                      configured &&
                                          !loading &&
                                          oauthLoading == null
                                      ? submitEmail
                                      : null,
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(56),
                                    backgroundColor: const Color(0xFF0877F9),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: const Color(
                                      0xFFB8C8DE,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                    textStyle: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -.15,
                                    ),
                                  ),
                                  child: loading
                                      ? const SizedBox.square(
                                          dimension: 21,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          authEntryText(
                                            context,
                                            AuthEntryCopyKey.verify,
                                          ),
                                        ),
                                ),
                                SizedBox(height: compact ? 24 : 30),
                                _OrDivider(
                                  label: authEntryText(
                                    context,
                                    AuthEntryCopyKey.orLabel,
                                  ),
                                ),
                                SizedBox(height: compact ? 18 : 22),
                                _oauthButton(
                                  key: const Key('oauth-google'),
                                  provider: OAuthProvider.google,
                                  label: authEntryText(
                                    context,
                                    AuthEntryCopyKey.continueGoogle,
                                  ),
                                  brand: SvgPicture.asset(
                                    'assets/branding/google_g.svg',
                                    width: 23,
                                    height: 23,
                                  ),
                                ),
                                const SizedBox(height: 11),
                                _oauthButton(
                                  key: const Key('oauth-apple'),
                                  provider: OAuthProvider.apple,
                                  label: authEntryText(
                                    context,
                                    AuthEntryCopyKey.continueApple,
                                  ),
                                  brand: Icon(
                                    Icons.apple,
                                    size: 27,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                if (AppEnvironment.facebookLoginEnabled) ...[
                                  const SizedBox(height: 11),
                                  _oauthButton(
                                    key: const Key('oauth-facebook'),
                                    provider: OAuthProvider.facebook,
                                    available:
                                        AppEnvironment.facebookLoginReady,
                                    label: authEntryText(
                                      context,
                                      AuthEntryCopyKey.continueFacebook,
                                    ),
                                    brand: const Icon(
                                      Icons.facebook,
                                      color: Color(0xFF1877F2),
                                      size: 26,
                                    ),
                                  ),
                                ],
                                SizedBox(height: compact ? 18 : 26),
                                Center(
                                  child: TextButton.icon(
                                    key: const Key('store-reviewer-access'),
                                    onPressed: configured
                                        ? () => context.push('/reviewer-login')
                                        : null,
                                    icon: const Icon(
                                      Icons.verified_user_outlined,
                                      size: 18,
                                    ),
                                    label: Text(
                                      authFiveLocaleTextOf(
                                        context,
                                        'Store reviewer access',
                                        'دخول مراجع المتجر',
                                      ),
                                    ),
                                  ),
                                ),
                                Center(
                                  child: TextButton(
                                    key: const Key('login-privacy-policy'),
                                    onPressed: () =>
                                        context.push('/legal/privacy'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF0877F9),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 9,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    child: Text(
                                      authEntryText(
                                        context,
                                        AuthEntryCopyKey.privacyPolicy,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _emailDecoration(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return InputDecoration(
      filled: true,
      fillColor: dark
          ? scheme.surfaceContainerHighest
          : const Color(0xFFFDFDFE),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant, width: 1.3),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: .7),
          width: 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0877F9), width: 1.7),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.error, width: 1.6),
      ),
    );
  }

  Widget _oauthButton({
    required Key key,
    required OAuthProvider provider,
    required String label,
    required Widget brand,
    bool available = true,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final busy = oauthLoading == provider;
    final enabled = available && !loading && oauthLoading == null;
    return Material(
      key: key,
      color: dark ? scheme.surfaceContainerHigh : Colors.white,
      borderRadius: BorderRadius.circular(12),
      shadowColor: const Color(0x22000000),
      elevation: 5,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? () => submitOAuth(provider) : null,
        child: SizedBox(
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PositionedDirectional(
                start: 18,
                child: busy
                    ? SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.primary,
                        ),
                      )
                    : SizedBox(width: 28, child: Center(child: brand)),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 48, end: 48),
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: enabled
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant.withValues(alpha: .7),
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ),
              if (!available)
                PositionedDirectional(
                  key: const Key('oauth-facebook-soon-glass'),
                  start: 56,
                  end: 0,
                  top: 0,
                  bottom: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadiusDirectional.only(
                      topEnd: Radius.circular(12),
                      bottomEnd: Radius.circular(12),
                    ),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              (dark
                                      ? scheme.surfaceContainerHigh
                                      : Colors.white)
                                  .withValues(alpha: 0.72),
                              (dark
                                      ? scheme.primaryContainer
                                      : const Color(0xFFEAF3FF))
                                  .withValues(alpha: 0.78),
                            ],
                          ),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Container(
                            key: const Key('oauth-facebook-soon-badge'),
                            margin: const EdgeInsetsDirectional.only(end: 14),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D6EFD),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x300D6EFD),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Text(
                              'SOON',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
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
        ),
      ),
    );
  }
}

class _AuthTopBar extends StatelessWidget {
  const _AuthTopBar({
    required this.title,
    required this.backKey,
    required this.onBack,
  });

  final String title;
  final Key backKey;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: dark ? scheme.surfaceContainerLow : const Color(0xFFFAFAFC),
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 16),
              child: Material(
                color: dark ? scheme.surfaceContainerHighest : Colors.white,
                shape: const CircleBorder(),
                elevation: 4,
                shadowColor: const Color(0x1F000000),
                child: IconButton(
                  key: backKey,
                  tooltip: authEntryText(context, AuthEntryCopyKey.back),
                  onPressed: onBack,
                  icon: Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.arrow_forward_ios_rounded
                        : Icons.arrow_back_ios_new_rounded,
                    size: 19,
                  ),
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 74),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Divider(color: scheme.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: scheme.outlineVariant)),
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: scheme.onErrorContainer, height: 1.35),
      ),
    );
  }
}
