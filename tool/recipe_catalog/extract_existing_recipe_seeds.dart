import 'dart:convert';
import 'dart:io';

String field(String block, String name) =>
    RegExp("$name: '([^']*)'", multiLine: true).firstMatch(block)?.group(1) ??
    '';

List<String> stringList(String block, String name) {
  final match = RegExp('$name: \\[(.*?)\\],', dotAll: true).firstMatch(block);
  if (match == null) return const [];
  return RegExp(
    "'([^']*)'",
  ).allMatches(match.group(1)!).map((m) => m.group(1)!).toList();
}

Map<String, Object?> ingredient(String text, int index) {
  final normalized = text.trim();
  final match = RegExp(
    r'^(\d+(?:\.\d+)?|\d+\/\d+)\s+(cup|cups|tbsp|tsp|g|kg|ml|l)\b\s*(.*)$',
    caseSensitive: false,
  ).firstMatch(normalized);
  num? quantity;
  String? unit;
  var label = normalized;
  if (match != null) {
    final raw = match.group(1)!;
    quantity = raw.contains('/')
        ? int.parse(raw.split('/')[0]) / int.parse(raw.split('/')[1])
        : num.parse(raw);
    unit = match.group(2)!.toLowerCase();
    label = match.group(3)!.trim();
  } else {
    final counted = RegExp(
      r'^(\d+(?:\.\d+)?|\d+\/\d+)\s+(.+)$',
    ).firstMatch(normalized);
    if (counted != null) {
      final raw = counted.group(1)!;
      quantity = raw.contains('/')
          ? int.parse(raw.split('/')[0]) / int.parse(raw.split('/')[1])
          : num.parse(raw);
      unit = 'item';
      label = counted.group(2)!.trim();
    }
  }
  final id = label
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return {
    'itemId': id.isEmpty ? 'ingredient-${index + 1}' : id,
    'quantity': quantity,
    'unit': unit,
  };
}

String sha256Text(String value) {
  // Pure Dart SHA-256 avoids a package dependency in this audit tool.
  final bytes = utf8.encode(value);
  final bitLength = bytes.length * 8;
  final data = <int>[...bytes, 0x80];
  while (data.length % 64 != 56) {
    data.add(0);
  }
  for (var shift = 56; shift >= 0; shift -= 8) {
    data.add((bitLength >> shift) & 0xff);
  }
  const k = <int>[
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];
  final h = <int>[
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ];
  int r(int x, int n) => ((x >>> n) | (x << (32 - n))) & 0xffffffff;
  for (var off = 0; off < data.length; off += 64) {
    final w = List<int>.filled(64, 0);
    for (var i = 0; i < 16; i++) {
      final p = off + i * 4;
      w[i] =
          (data[p] << 24) |
          (data[p + 1] << 16) |
          (data[p + 2] << 8) |
          data[p + 3];
    }
    for (var i = 16; i < 64; i++) {
      final s0 = r(w[i - 15], 7) ^ r(w[i - 15], 18) ^ (w[i - 15] >>> 3);
      final s1 = r(w[i - 2], 17) ^ r(w[i - 2], 19) ^ (w[i - 2] >>> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
    }
    var a = h[0],
        b = h[1],
        c = h[2],
        d = h[3],
        e = h[4],
        f = h[5],
        g = h[6],
        hh = h[7];
    for (var i = 0; i < 64; i++) {
      final s1 = r(e, 6) ^ r(e, 11) ^ r(e, 25);
      final ch = (e & f) ^ ((~e) & g);
      final t1 = (hh + s1 + ch + k[i] + w[i]) & 0xffffffff;
      final s0 = r(a, 2) ^ r(a, 13) ^ r(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & 0xffffffff;
      hh = g;
      g = f;
      f = e;
      e = (d + t1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & 0xffffffff;
    }
    final v = [a, b, c, d, e, f, g, hh];
    for (var i = 0; i < 8; i++) {
      h[i] = (h[i] + v[i]) & 0xffffffff;
    }
  }
  return h.map((v) => v.toRadixString(16).padLeft(8, '0')).join();
}

void main() {
  final source = File(
    'lib/features/wellness/presentation/recipe_library_page.dart',
  ).readAsStringSync();
  final inventory = File(
    'artifacts/meal_catalog/existing_recipe_image_inventory.csv',
  ).readAsLinesSync().skip(1).map((line) => line.split(',')).toList();
  final images = {for (final r in inventory) r[0]: r};
  final records = <Map<String, Object?>>[];
  for (final match in RegExp(
    r'_Recipe\((.*?)\n  \),',
    dotAll: true,
  ).allMatches(source)) {
    final block = match.group(1)!;
    final id = field(block, 'id');
    if (id.isEmpty) continue;
    final title = field(block, 'titleEn');
    final arTitle = field(block, 'titleAr');
    final path =
        RegExp(
          r"imageAsset:\s*'([^']+)'",
          dotAll: true,
        ).firstMatch(block)?.group(1) ??
        '';
    final inv = images[path];
    final enIng = stringList(block, 'ingredientsEn');
    final arIng = stringList(block, 'ingredientsAr');
    final enSteps = stringList(block, 'stepsEn');
    final arSteps = stringList(block, 'stepsAr');
    final minutes = int.parse(
      RegExp(r'minutes: (\d+)').firstMatch(block)!.group(1)!,
    );
    final canonicalId = id.replaceAll('_', '-');
    final normalized = [
      title.toLowerCase(),
      ...enIng.map((e) => e.toLowerCase()),
      ...enSteps.map((e) => e.toLowerCase()),
    ].join('|');
    records.add({
      'canonicalId': canonicalId,
      'contentFingerprint': sha256Text(normalized),
      'origin': 'bil-original',
      'primaryLocale': 'en',
      'region': 'global',
      'countryTags': ['global'],
      'mealTypes': [
        title.toLowerCase().contains(RegExp('oat|omelet|shakshuka'))
            ? 'breakfast'
            : 'lunch',
      ],
      'allergens': <String>[],
      'dietTags': [field(block, 'category')],
      'budgetTier': 'unknown',
      'serving': {'count': null, 'size': null, 'unit': null},
      'timing': {
        'prepMinutes': null,
        'cookMinutes': null,
        'totalMinutes': minutes,
      },
      'ingredients': [
        for (var i = 0; i < enIng.length; i++) ingredient(enIng[i], i),
      ],
      'method': [
        for (var i = 0; i < enSteps.length; i++)
          {'order': i + 1, 'instructionKey': '$canonicalId-step-${i + 1}'},
      ],
      'localizations': {
        'en': {
          'title': title,
          'ingredients': enIng,
          'steps': enSteps,
          'translationStatus': 'native-reviewed',
        },
        if (arTitle.isNotEmpty && arIng.isNotEmpty && arSteps.isNotEmpty)
          'ar': {
            'title': arTitle,
            'ingredients': arIng,
            'steps': arSteps,
            'translationStatus': 'native-reviewed',
          },
      },
      'nutrition': {
        'status': 'pending',
        'servings': null,
        'sourceRefs': <String>[],
        'reviewedAt': null,
        'perServing': {
          'kcal': null,
          'proteinG': null,
          'carbohydrateG': null,
          'fatG': null,
          'fiberG': null,
          'sugarG': null,
          'sodiumMg': null,
          'potassiumMg': null,
        },
      },
      'image': {
        'status': 'existing-unreviewed',
        'assetPath': path,
        'sha256': inv?[4],
        'width': inv == null ? null : int.parse(inv[1]),
        'height': inv == null ? null : int.parse(inv[2]),
        'provenance': 'existing asset; provenance and human review pending',
        'promptId': null,
      },
    });
  }
  final out = {
    'schemaVersion': 1,
    'claims': {
      'marketedRecipeCount': 0,
      'marketedRecipeImageCount': 0,
      'marketedNutritionVerifiedCount': 0,
    },
    'records': records,
  };
  File(
    'artifacts/meal_catalog/existing_recipe_canonical_seeds.json',
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(out)}\n');
}
