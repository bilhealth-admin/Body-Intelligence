import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

const sources = <String, String>{
  'sopa-tortilla-pollo':
      'C:/Users/HP 1040 G8/.codex/generated_images/019fed3f-4eb7-7b22-a7c9-ca8dc9ae6f3a/exec-6a69d811-d2d9-4b8f-a424-410b8ab82c37.png',
  'pepian-pollo':
      'C:/Users/HP 1040 G8/.codex/generated_images/019fed3f-4eb7-7b22-a7c9-ca8dc9ae6f3a/exec-7789f3c8-4934-4e5e-8ede-6de558ed8829.png',
  'casamiento-hondureno':
      'C:/Users/HP 1040 G8/.codex/generated_images/019fed3f-4eb7-7b22-a7c9-ca8dc9ae6f3a/exec-8b35c9e6-1b36-467f-a1f7-cf8766422613.png',
};
void main() {
  final file = File(
    'artifacts/meal_catalog/recipe_canonical_100_verified.json',
  );
  final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final records = (data['records'] as List).cast<Map<String, dynamic>>();
  final ledger = File('artifacts/meal_catalog/meal_image_prompt_ledger.csv');
  var lines = ledger.readAsLinesSync();
  for (final e in sources.entries) {
    final bytes = File(e.value).readAsBytesSync();
    final hash = sha256.convert(bytes).toString();
    final target = 'assets/images/professional/recipes/generated/${e.key}.png';
    File(target).writeAsBytesSync(bytes, flush: true);
    final r = records.singleWhere((r) => r['canonicalId'] == e.key);
    final image = r['image'] as Map;
    if (image['status'] != 'planned') throw StateError('${e.key} not planned');
    r['image'] = {
      'status': 'generated-unreviewed',
      'assetPath': target,
      'sha256': hash,
      'width': 1256,
      'height': 1256,
      'provenance':
          'Generated original BIL asset; visual identity/content inspection passed internally; human release review remains required.',
      'promptId': image['promptId'],
    };
    final i = lines.indexWhere((l) => l.contains(',${e.key},'));
    if (i < 0) throw StateError('ledger missing ${e.key}');
    lines[i] = lines[i].replaceFirst(',planned,', ',generated-unreviewed,');
    if (!lines[i].endsWith(',,'))
      throw StateError('ledger asset occupied ${e.key}');
    lines[i] = '${lines[i].substring(0, lines[i].length - 2)},$target,$hash';
  }
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(data)}\n',
  );
  ledger.writeAsStringSync('${lines.join('\n')}\n');
}
// ignore_for_file: curly_braces_in_flow_control_structures
