import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/services/app_settings_provider.dart';

class WelcomeStep extends ConsumerWidget {
  const WelcomeStep({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    final locale = ref.watch(appSettingsProvider).localeCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'en', label: Text('English')),
              ButtonSegment(value: 'ar', label: Text('العربية')),
            ],
            selected: {locale},
            showSelectedIcon: true,
            onSelectionChanged: (selection) {
              ref
                  .read(appSettingsProvider.notifier)
                  .setLocale(selection.single);
            },
          ),
        ),
        const Spacer(),
        Semantics(
          header: true,
          child: Text(
            strings.get('onboarding_title'),
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          strings.get('onboarding_body'),
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 24),
        _Promise(
          icon: Icons.visibility_outlined,
          title: context.strings.text('Understand every insight'),
          body: context.strings.text(
            'See the evidence, confidence, and what BIL still does not know.',
          ),
        ),
        const SizedBox(height: 12),
        _Promise(
          icon: Icons.phonelink_lock_outlined,
          title: context.strings.text('Private and useful offline'),
          body: context.strings.text(
            'Start without an account. Your health data stays on this device.',
          ),
        ),
        const SizedBox(height: 12),
        _Promise(
          icon: Icons.science_outlined,
          title: context.strings.text('Honest about uncertainty'),
          body: context.strings.text(
            'BIL never invents missing evidence or pretends a guess is a fact.',
          ),
        ),
        const Spacer(),
        SizedBox(
          height: 58,
          child: FilledButton(
            onPressed: onContinue,
            child: Text(
              strings.get('start'),
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.strings.text('No account required. Nothing is uploaded.'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Promise extends StatelessWidget {
  const _Promise({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(body, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}
