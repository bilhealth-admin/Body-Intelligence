import 'dart:io';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan_privacy_copy.dart';

/// Static English copy only. Runtime values and interpolated health data must
/// never be sent to a translation service or treated as catalogue keys.
Future<Set<String>> smartPlanCopySources() async {
  final values = <String>{
    bilSmartPlanBackupPrivacyTitle,
    bilSmartPlanBackupPrivacyEnglish,
    'My Smart Plan',
    'Replace your current plan with this reviewed draft? The previous plan stays on this device. Diary records will not change.',
    'Plan change saved and verified.',
    'Training, nutrition and progress in one place',
  };
  final calls = RegExp(
    r'''\b(?:(?:_t|t)\(|_smartPlanText\(\s*context,)\s*((?:(?:'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*")\s*)+),''',
    multiLine: true,
  );
  final strings = RegExp(r'''('(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*")''');
  final files = <File>[
    await for (final entry in Directory(
      'lib/features/smart_plan/presentation',
    ).list())
      if (entry is File && entry.path.endsWith('.dart')) entry,
    File('lib/features/life_context/coach_memory_sync_review_panel.dart'),
  ];
  for (final file in files) {
    for (final call in calls.allMatches(await file.readAsString())) {
      final pieces = strings.allMatches(call.group(1)!).map((token) {
        final quoted = token.group(1)!;
        return quoted.substring(1, quoted.length - 1);
      }).toList();
      if (pieces.any((piece) => piece.contains(r'$'))) continue;
      values.add(
        pieces
            .join()
            .replaceAll(r"\'", "'")
            .replaceAll(r'\"', '"')
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\t', '\t')
            .replaceAll(r'\\', '\\'),
      );
    }
  }
  return values;
}
