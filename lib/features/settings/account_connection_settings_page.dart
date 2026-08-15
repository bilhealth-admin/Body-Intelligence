import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';

enum AccountConnectionProvider { facebook, google }

class AccountConnectionSettingsPage extends StatelessWidget {
  const AccountConnectionSettingsPage({super.key, required this.provider});

  final AccountConnectionProvider provider;

  String get _name => switch (provider) {
    AccountConnectionProvider.facebook => 'Facebook',
    AccountConnectionProvider.google => 'Google',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.strings.text('$_name settings'))),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(
          provider == AccountConnectionProvider.facebook
              ? Icons.facebook_rounded
              : Icons.account_circle_outlined,
          size: 52,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 20),
        Text(
          context.strings.text('Account linking is unavailable on this build.'),
          key: const Key('account-linking-unavailable'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Text(
          context.strings.text(
            'BIL will enable this control only after the provider consent and account-linking flow is verified.',
          ),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          key: Key('connect-${provider.name}'),
          onPressed: null,
          icon: const Icon(Icons.link_off_rounded),
          label: Text(context.strings.text('Connect $_name')),
        ),
      ],
    ),
  );
}
