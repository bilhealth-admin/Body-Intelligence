import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../visual_closure/visual_evidence_font.dart';

String mealEvidenceFontFamily = 'RobotoEvidence';

/// Painted Windows evidence uses its real system sans instead of forcing the
/// editorial Naskh asset onto an app whose production theme uses system fonts.
/// No font binaries are copied or bundled. CI keeps the existing SDK fallback.
Future<void> loadMealPlatformEvidenceFont() async {
  await loadVisualEvidenceFont();
  if (!Platform.isWindows) return;
  final system = Platform.environment['SystemRoot'];
  if (system == null) return;
  final fonts = [
    'segoeui.ttf',
    'seguisb.ttf',
    'segoeuib.ttf',
  ].map((name) => File('$system/Fonts/$name')).toList();
  if (fonts.any((file) => !file.existsSync())) return;
  final loader = FontLoader('LocalPlatformMealEvidence');
  for (final font in fonts) {
    loader.addFont(
      font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
  }
  await loader.load();
  mealEvidenceFontFamily = 'LocalPlatformMealEvidence';
}

ThemeData mealPlatformEvidenceTheme(ThemeData theme) =>
    visualEvidenceTheme(theme, fontFamily: mealEvidenceFontFamily);
