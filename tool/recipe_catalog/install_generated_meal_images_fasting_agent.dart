import 'dart:convert';
import 'dart:io';

const _sourceRoot =
    r'C:\Users\HP 1040 G8\.codex\generated_images\019fed3f-4eb7-7b22-a7c9-ca8dc9ae6f3a';
const _assetRoot = 'assets/images/professional/recipes/generated';
const _manifestPath =
    'artifacts/meal_catalog/generated_meal_images_fasting_agent.json';

const _files = <String, String>{
  'sopa-tortilla-pollo': 'exec-6a69d811-d2d9-4b8f-a424-410b8ab82c37.png',
  'pepian-pollo': 'exec-7789f3c8-4934-4e5e-8ede-6de558ed8829.png',
  'casamiento-hondureno': 'exec-8b35c9e6-1b36-467f-a1f7-cf8766422613.png',
  'seco-pollo-quinoa': 'exec-cc7f7d4a-0a52-4979-a5f2-43871e56a9fd.png',
  'cazuela-pescado': 'exec-393b9ff4-74dd-40ba-8d4f-24c42ea56271.png',
  'sancocho-pollo': 'exec-84c29c91-7ff0-4777-b6b5-eb6d76d844d8.png',
  'frijoles-negros-calabaza': 'exec-18997683-3311-4443-8691-3d7b3daa7ccb.png',
  'enchiladas-frijol-pollo': 'exec-2305baa9-a13a-48b5-ab2a-27c01b71e90e.png',
  'tekirdag-kofte-bulgur': 'exec-285b97cc-8879-4d59-acc9-5299025add22.png',
  'zeytinyagli-pirasa': 'exec-f659d9c0-f379-4d0d-9959-897f1ebc9a86.png',
  'ege-zeytinyagli-enginar': 'exec-935eff66-3718-4619-a693-507477acf83c.png',
  'otlu-borek-yogurt': 'exec-76e1a32e-dfdf-426d-ac9e-be184de79465.png',
};

Future<String> _sha256(File file) async {
  final result = await Process.run(
    'powershell',
    ['-NoProfile', '-Command', '(Get-FileHash -Algorithm SHA256 -LiteralPath "${file.absolute.path}").Hash.ToLowerInvariant()'],
  );
  if (result.exitCode != 0) {
    throw StateError('Unable to hash ${file.path}: ${result.stderr}');
  }
  return '${result.stdout}'.trim();
}

Future<void> main() async {
  final output = Directory(_assetRoot)..createSync(recursive: true);
  final records = <Map<String, Object>>[];
  final hashes = <String>{};
  for (final entry in _files.entries) {
    final source = File('$_sourceRoot/${entry.value}');
    if (!source.existsSync()) throw StateError('Missing source: ${source.path}');
    final target = File('${output.path}/${entry.key}.png');
    source.copySync(target.path);
    final hash = await _sha256(target);
    if (!hashes.add(hash)) throw StateError('Duplicate SHA256: ${entry.key}');
    records.add({
      'canonicalId': entry.key,
      'assetPath': target.path.replaceAll('\\', '/'),
      'sha256': hash,
      'width': 1256,
      'height': 1256,
      'visualStatus': 'confirmed',
      'source': 'openai-imagegen',
      'sourceFile': entry.value,
    });
  }
  final manifest = File(_manifestPath)..parent.createSync(recursive: true);
  manifest.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert({
    'schemaVersion': 1,
    'batchOwner': 'fasting_runtime_reliability',
    'status': 'visually-confirmed',
    'count': records.length,
    'records': records,
  })}\n');
  stdout.writeln('INSTALLED=${records.length} UNIQUE_SHA=${hashes.length}');
}
