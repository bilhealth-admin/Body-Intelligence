import 'package:flutter/material.dart';
import '../../app/localization/app_localizations.dart';

class ActionableErrorState extends StatelessWidget {
  const ActionableErrorState({
    super.key,
    required this.title,
    this.body,
    required this.onRetry,
    this.icon = Icons.storage_outlined,
  });

  final String title;
  final String? body;
  final VoidCallback onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final defaultBody = context.strings.text(
      'Your data was not reset or uploaded. Try opening it again.',
    );
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 8),
              Text(body ?? defaultBody, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(context.strings.text('Try again')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
