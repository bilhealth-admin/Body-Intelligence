import 'dart:io';

import 'package:body_intelligence_log/app/theme/app_theme_data.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release themes preserve native iOS and Android route behavior', () {
    final themes = <ThemeData>[
      BilFlagshipTheme.light(),
      BilFlagshipTheme.dark(),
      AppThemeData.lightTheme(Brightness.light),
      AppThemeData.lightTheme(Brightness.dark),
    ];

    for (final theme in themes) {
      expect(
        theme.pageTransitionsTheme.builders[TargetPlatform.iOS],
        isA<CupertinoPageTransitionsBuilder>(),
        reason:
            'iPhone and iPad routes must retain the native horizontal '
            'transition and interactive edge-swipe back gesture.',
      );
      expect(
        theme.pageTransitionsTheme.builders[TargetPlatform.android],
        isA<PredictiveBackPageTransitionsBuilder>(),
        reason: 'Android routes must retain predictive-back integration.',
      );
    }
  });

  test(
    'Android manifest opts into predictive back on Android 13 through 15',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifest, contains('android:enableOnBackInvokedCallback="true"'));
    },
  );
}
