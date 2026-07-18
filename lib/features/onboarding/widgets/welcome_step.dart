import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';

class WelcomeStep extends StatelessWidget {
  final VoidCallback onContinue;

  const WelcomeStep({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          width: double.infinity,
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
