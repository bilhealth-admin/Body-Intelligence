part of 'recipe_release_repository.dart';

void _validateSourceReconciliation(Object? raw) {
  if (raw is! Map<String, dynamic>) {
    throw const FormatException('Recipe source revision is invalid.');
  }
  _exactKeys(raw, const {
    'revision',
    'recovered_formulation_count',
    'formulation_evidence_sha256',
    'food_database_sha256',
    'food_snapshot_sha256',
    'formula',
    'weighing_basis',
    'missing_optional_policy',
    'core_nutrients_calculated_record_count',
    'optional_unknowns',
  });
  for (final key in const [
    'formulation_evidence_sha256',
    'food_database_sha256',
    'food_snapshot_sha256',
  ]) {
    _digest(raw[key]);
  }
  if (raw['revision'] != 'bil-source-reconciled-20260910-v1' ||
      raw['recovered_formulation_count'] != 34 ||
      raw['core_nutrients_calculated_record_count'] != 1500 ||
      raw['formula'] != 'sum(per100g * grams / 100) / servings' ||
      raw['optional_unknowns'] is! List) {
    throw const FormatException('Recipe source revision is unsupported.');
  }
  _text(raw['weighing_basis'], 'weighing_basis');
  _text(raw['missing_optional_policy'], 'missing_optional_policy');
  final ids = <String>{};
  for (final entry in raw['optional_unknowns'] as List) {
    if (entry is! Map<String, dynamic>) {
      throw const FormatException('Unknown nutrient evidence is invalid.');
    }
    _exactKeys(entry, const {'recipe', 'nutrients'});
    final id = _text(entry['recipe'], 'recipe');
    final nutrients = _strings(entry['nutrients'], 'nutrients');
    if (!ids.add(id) ||
        nutrients.isEmpty ||
        nutrients.any(
          (value) => !const {
            'fiberG',
            'sugarG',
            'sodiumMg',
            'potassiumMg',
          }.contains(value),
        )) {
      throw const FormatException('Unknown nutrient declaration is invalid.');
    }
  }
}

Map<String, dynamic> _decodeObject(Uint8List bytes) {
  final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Recipe release asset must be an object.');
  }
  return decoded;
}

void _verifyBytes(
  Uint8List bytes, {
  required int expectedBytes,
  required String expectedSha256,
}) {
  if (bytes.length != expectedBytes ||
      sha256.convert(bytes).toString() != expectedSha256) {
    throw const FormatException('Recipe release asset integrity mismatch.');
  }
}

void _exactKeys(Map<String, dynamic> value, Set<String> expected) {
  if (value.keys.toSet().difference(expected).isNotEmpty ||
      expected.difference(value.keys.toSet()).isNotEmpty) {
    throw const FormatException('Recipe release fields are invalid.');
  }
}

String _text(Object? value, String field) {
  if (value is! String || value.isEmpty || value != value.trim()) {
    throw FormatException('$field is invalid.');
  }
  return value;
}

String _digest(Object? value) {
  final result = _text(value, 'digest');
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(result)) {
    throw const FormatException('Digest is invalid.');
  }
  return result;
}

int _integer(Object? value, String field) {
  if (value is! int || value < 0) throw FormatException('$field is invalid.');
  return value;
}

int _positiveInteger(Object? value, String field) {
  final result = _integer(value, field);
  if (result <= 0) throw FormatException('$field must be positive.');
  return result;
}

List<String> _strings(Object? value, String field) {
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('$field is invalid.');
  }
  return List<String>.unmodifiable(value.cast<String>());
}

Map<String, String> _stringMap(Object? value, String field) {
  if (value is! Map<String, dynamic> ||
      value.isEmpty ||
      value.values.any((item) => item is! String || item.trim().isEmpty)) {
    throw FormatException('$field is invalid.');
  }
  return Map<String, String>.unmodifiable(value.cast<String, String>());
}
