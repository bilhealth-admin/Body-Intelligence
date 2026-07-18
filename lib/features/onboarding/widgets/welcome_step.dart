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
        Text(
          strings.get('onboarding_title'),
          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Text(
          strings.get('onboarding_body'),
          style: const TextStyle(fontSize: 18),
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
      ],
    );
  }
}
