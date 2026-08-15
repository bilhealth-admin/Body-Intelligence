import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../localization/app_localizations.dart';

class InvalidRoutePage extends StatelessWidget {
  const InvalidRoutePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.get('app_title'))),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_off_rounded, size: 48),
                const SizedBox(height: 16),
                Text(
                  context.strings.get('invalid_link'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.go('/dashboard'),
                  icon: const Icon(Icons.home_outlined),
                  label: Text(context.strings.get('dashboard')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
