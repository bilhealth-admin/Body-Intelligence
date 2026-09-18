import 'package:flutter/material.dart';

class AuthStatusPanel extends StatelessWidget {
  const AuthStatusPanel({super.key, required this.message});

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
