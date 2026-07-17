import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/startup/startup_page.dart';

void main() {
  runApp(
    const ProviderScope(
      child: BILApp(),
    ),
  );
}

class BILApp extends StatelessWidget {
  const BILApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BIL – Body Intelligence Log',
      theme: AppTheme.lightTheme,
      home: const StartupPage(),
    );
  }
}