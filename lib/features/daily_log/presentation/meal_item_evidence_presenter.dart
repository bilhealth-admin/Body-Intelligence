import '../../../data/database/app_database.dart';

class MealItemEvidencePresenter {
  const MealItemEvidencePresenter._();

  static String subtitle({
    required MealItem item,
    required String mealLabel,
    required String languageCode,
  }) {
    final quantity = _formatQuantity(item.quantity);
    final unit = _unitLabel(item.servingUnitSnapshot, languageCode);
    final source = sourceLabel(
      item.foodSourceSnapshot,
      verified: item.foodVerifiedSnapshot,
      languageCode: languageCode,
    );
    final serving = _servingLabel(
      item.servingSizeSnapshot,
      item.servingUnitSnapshot,
      languageCode: languageCode,
    );

    return '$mealLabel · $quantity $unit · $source · ${_copy(languageCode, 'reference')} $serving';
  }

  static String sourceLabel(
    String source, {
    required bool verified,
    required String languageCode,
  }) {
    final normalized = source.trim().toLowerCase();
    final label = switch (normalized) {
      'usda' => _copy(languageCode, 'usda'),
      'branded' => _copy(languageCode, 'branded'),
      'catalog' => _copy(languageCode, 'catalog'),
      'local' => _copy(languageCode, 'local'),
      _ => _copy(languageCode, 'saved'),
    };

    if (verified || normalized == 'usda') return label;
    return '$label — ${_copy(languageCode, 'unverified')}';
  }

  static String _servingLabel(
    double size,
    String unit, {
    required String languageCode,
  }) {
    return '${_formatQuantity(size)} ${_unitLabel(unit, languageCode)}';
  }

  static String _unitLabel(String unit, String languageCode) {
    final normalized = unit.trim().toLowerCase();
    return switch (normalized) {
      'g' || 'gram' || 'grams' => languageCode == 'ar' ? 'غم' : 'g',
      'ml' ||
      'milliliter' ||
      'milliliters' => languageCode == 'ar' ? 'مل' : 'ml',
      'piece' || 'pieces' => _copy(languageCode, 'piece'),
      'serving' || 'servings' => _copy(languageCode, 'serving'),
      _ => unit.trim().isEmpty ? _copy(languageCode, 'unit') : unit.trim(),
    };
  }

  static String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  static String _copy(String languageCode, String key) =>
      _evidenceCopy[languageCode]?[key] ?? _evidenceCopy['en']![key]!;
}

const _evidenceCopy = <String, Map<String, String>>{
  'en': {
    'reference': 'reference serving',
    'usda': 'Verified USDA',
    'branded': 'Verified branded food',
    'catalog': 'Verified catalog',
    'local': 'Local entry',
    'saved': 'Saved source',
    'unverified': 'unverified',
    'piece': 'piece',
    'serving': 'serving',
    'unit': 'unit',
  },
  'ar': {
    'reference': 'الحصة المرجعية',
    'usda': 'USDA موثّق',
    'branded': 'منتج موثّق',
    'catalog': 'كتالوج موثّق',
    'local': 'إدخال محلي',
    'saved': 'مصدر محفوظ',
    'unverified': 'غير موثّق',
    'piece': 'قطعة',
    'serving': 'حصة',
    'unit': 'وحدة',
  },
  'fr': {
    'reference': 'portion de référence',
    'usda': 'USDA vérifié',
    'branded': 'aliment de marque vérifié',
    'catalog': 'catalogue vérifié',
    'local': 'entrée locale',
    'saved': 'source enregistrée',
    'unverified': 'non vérifié',
    'piece': 'pièce',
    'serving': 'portion',
    'unit': 'unité',
  },
  'es': {
    'reference': 'porción de referencia',
    'usda': 'USDA verificado',
    'branded': 'alimento de marca verificado',
    'catalog': 'catálogo verificado',
    'local': 'entrada local',
    'saved': 'fuente guardada',
    'unverified': 'no verificado',
    'piece': 'pieza',
    'serving': 'porción',
    'unit': 'unidad',
  },
  'tr': {
    'reference': 'referans porsiyon',
    'usda': 'Doğrulanmış USDA',
    'branded': 'doğrulanmış markalı gıda',
    'catalog': 'doğrulanmış katalog',
    'local': 'yerel giriş',
    'saved': 'kayıtlı kaynak',
    'unverified': 'doğrulanmamış',
    'piece': 'adet',
    'serving': 'porsiyon',
    'unit': 'birim',
  },
};
