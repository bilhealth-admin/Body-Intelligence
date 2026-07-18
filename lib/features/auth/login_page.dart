import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/environment/app_environment.dart';
import '../../app/localization/app_localizations.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.strings.text;
    final configured = AppEnvironment.cloudConfigured;
    return Scaffold(
      appBar: AppBar(title: Text(t('BIL account'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      t('Your data, on your terms'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t(
                        'Cloud accounts are optional. Local Mode remains fully usable and keeps data on this device.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: email,
                      enabled: configured,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                      decoration: InputDecoration(
                        labelText: t('Email'),
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: password,
                      enabled: configured,
                      obscureText: obscure,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: t('Password'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: t(
                            obscure ? 'Show password' : 'Hide password',
                          ),
                          onPressed: configured
                              ? () => setState(() => obscure = !obscure)
                              : null,
                          icon: Icon(
                            obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.login),
                      label: Text(t('Sign in')),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      configured
                          ? t(
                              'Account sign-in remains disabled until the verified server auth boundary is initialized.',
                            )
                          : t(
                              'Cloud accounts are not configured in this build. No credentials will be accepted or stored.',
                            ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/onboarding'),
                      icon: const Icon(Icons.phone_android),
                      label: Text(t('Continue in Local Mode')),
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
