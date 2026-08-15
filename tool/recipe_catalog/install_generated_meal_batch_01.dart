import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

const ids = <String>[
  'egyptian-koshari',
  'ful-medames-tahini',
  'palestinian-musakhan',
  'maqluba-eggplant-chicken',
  'chicken-kabsa',
  'harees-chicken',
  'iraqi-masgouf-rice',
  'iraqi-dolma',
  'moroccan-harira',
  'tunisian-couscous-vegetables',
  'bamia-beef-egyptian',
  'fatta-chicken',
];
const files = <String>[
  'exec-875c52ea-8848-4296-8538-ffa3ffc1ca72.png',
  'exec-ab62ac10-3274-4429-b9ac-4145a24b2546.png',
  'exec-b2daf1bc-4012-4936-afc7-b6db768655d8.png',
  'exec-76a56f0a-0ab1-4462-a2db-524966c62c0d.png',
  'exec-075f8941-5cf2-499b-917b-7e6df9af9edf.png',
  'exec-7a52786c-5532-487c-af01-25cbc77380bc.png',
  'exec-501882c9-a79a-48fd-86d8-608113730d1f.png',
  'exec-d7400978-df40-438e-9a30-729300e58b33.png',
  'exec-dfb2aa94-57b4-4e8f-842f-39379384ebd4.png',
  'exec-faa5f57c-70d4-4846-977f-bab826a5bd0e.png',
  'exec-1d89afbb-075c-4c8b-82c5-11d41e1e4404.png',
  'exec-581aee59-e26f-452c-bedc-7b4d89b3ba3a.png',
];

void main() {
  const sourceDir =
      'C:/Users/HP 1040 G8/.codex/generated_images/019fe03b-4022-78b3-9a9b-749cf5a9aa79';
  const outDir = 'assets/images/professional/recipes/generated';
  Directory(outDir).createSync(recursive: true);
  final catalogFile = File(
    'artifacts/meal_catalog/recipe_canonical_100_verified.json',
  );
  final catalog =
      jsonDecode(catalogFile.readAsStringSync()) as Map<String, dynamic>;
  final records = (catalog['records'] as List).cast<Map<String, dynamic>>();
  final seen = <String>{};
  for (var i = 0; i < ids.length; i++) {
    final source = File('$sourceDir/${files[i]}');
    if (!source.existsSync())
      throw StateError('Missing generated source: ${files[i]}');
    final bytes = source.readAsBytesSync();
    final hash = sha256.convert(bytes).toString();
    if (!seen.add(hash))
      throw StateError('Duplicate generated image SHA: $hash');
    final target = File('$outDir/${ids[i]}.png');
    target.writeAsBytesSync(bytes, flush: true);
    final r = records.singleWhere((e) => e['canonicalId'] == ids[i]);
    final image = (r['image'] as Map).cast<String, dynamic>();
    if (image['status'] != 'planned')
      throw StateError('${ids[i]} is not planned');
    r['image'] = {
      'status': 'generated-unreviewed',
      'assetPath': '$outDir/${ids[i]}.png',
      'sha256': hash,
      'width': 1256,
      'height': 1256,
      'provenance':
          'Generated original BIL asset; visual identity/content inspection passed internally; human release review remains required.',
      'promptId': image['promptId'],
    };
  }
  catalogFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(catalog)}\n',
  );
  final ledger = File('artifacts/meal_catalog/meal_image_prompt_ledger.csv');
  var text = ledger.readAsStringSync();
  var ledgerLines = text.split('\n');
  if (!ledgerLines.first.endsWith(',asset_path,asset_sha256')) {
    ledgerLines = [
      ledgerLines.first + ',asset_path,asset_sha256',
      for (final line in ledgerLines.skip(1))
        if (line.isNotEmpty) '$line,,',
    ];
    text = ledgerLines.join('\n') + '\n';
  }
  for (var i = 0; i < ids.length; i++) {
    final hash = sha256
        .convert(File('$sourceDir/${files[i]}').readAsBytesSync())
        .toString();
    final lines = text.split('\n');
    final index = lines.indexWhere((l) => l.contains(',${ids[i]},'));
    if (index < 0) throw StateError('Ledger row missing: ${ids[i]}');
    lines[index] = lines[index].replaceFirst(
      ',planned,',
      ',generated-unreviewed,',
    );
    if (!lines[index].endsWith(',,'))
      throw StateError('Ledger asset columns already populated: ${ids[i]}');
    lines[index] =
        '${lines[index].substring(0, lines[index].length - 2)},$outDir/${ids[i]}.png,$hash';
    text = lines.join('\n');
  }
  ledger.writeAsStringSync(text);
}
// ignore_for_file: curly_braces_in_flow_control_structures, prefer_interpolation_to_compose_strings
