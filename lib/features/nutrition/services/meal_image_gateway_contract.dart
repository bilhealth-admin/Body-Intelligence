import 'dart:convert';

const maximumMealImageBytes = 12 * 1024 * 1024;
const maximumMealImageResponseBytes = 256 * 1024;
const maximumMealImageCandidates = 8;

double? mealImageAmountInGrams({
  required double amount,
  required String unit,
  required double servingSize,
  required String servingUnit,
}) {
  if (!amount.isFinite ||
      amount <= 0 ||
      !servingSize.isFinite ||
      servingSize <= 0) {
    return null;
  }
  final normalized = unit.trim().toLowerCase();
  if (const {'g', 'gram', 'grams', 'gm', 'جم'}.contains(normalized)) {
    return amount;
  }
  if (const {'kg', 'kilogram', 'kilograms', 'كجم'}.contains(normalized)) {
    return amount * 1000;
  }
  if (const {'oz', 'ounce', 'ounces'}.contains(normalized)) {
    return amount * 28.349523125;
  }
  if (const {'lb', 'lbs', 'pound', 'pounds'}.contains(normalized)) {
    return amount * 453.59237;
  }
  if (const {'mg', 'milligram', 'milligrams'}.contains(normalized)) {
    return amount / 1000;
  }
  if (normalized == servingUnit.trim().toLowerCase()) {
    return amount * servingSize;
  }
  return null;
}

enum MealImageAnalysisFailure {
  notConfigured,
  authenticationRequired,
  invalidImage,
  serviceUnavailable,
  rateLimited,
  nonFoodOrUnrecognized,
  invalidResponse,
}

class MealImageAnalysisException implements Exception {
  const MealImageAnalysisException(this.failure);
  final MealImageAnalysisFailure failure;
  String message({required bool arabic, String? languageCode}) {
    var code = languageCode?.toLowerCase();
    code ??= 'en';
    if (arabic && languageCode == null) code = 'ar';
    final values = _utf8Messages[failure]!;
    return values[code] ?? values['en']!;
  }

  @override
  String toString() => 'MealImageAnalysisException($failure)';
}

// ignore: unused_element
const _messages = <MealImageAnalysisFailure, Map<String, String>>{
  MealImageAnalysisFailure.notConfigured: {
    'en': 'Meal-image analysis is not configured for this build.',
    'ar': 'تحليل صور الوجبات غير مفعّل في هذا الإصدار.',
    'fr':
        'L’analyse des photos de repas n’est pas configurée dans cette version.',
    'es':
        'El análisis de imágenes de comidas no está configurado en esta versión.',
    'tr': 'Yemek görseli analizi bu sürüm için yapılandırılmamış.',
  },
  MealImageAnalysisFailure.authenticationRequired: {
    'en': 'Sign in before sending a meal image for secure analysis.',
    'ar': 'سجّل الدخول قبل إرسال صورة الوجبة للتحليل الآمن.',
    'fr':
        'Connectez-vous avant d’envoyer une photo de repas pour une analyse sécurisée.',
    'es':
        'Inicia sesión antes de enviar una imagen de comida para un análisis seguro.',
    'tr': 'Güvenli analiz için yemek görselini göndermeden önce oturum açın.',
  },
  MealImageAnalysisFailure.invalidImage: {
    'en': 'Choose a JPG, PNG, or WebP image up to 12 MB.',
    'ar': 'اختر صورة JPG أو PNG أو WebP بحجم لا يتجاوز 12 ميغابايت.',
    'fr': 'Choisissez une image JPG, PNG ou WebP de 12 Mo maximum.',
    'es': 'Elige una imagen JPG, PNG o WebP de hasta 12 MB.',
    'tr': 'En fazla 12 MB boyutunda JPG, PNG veya WebP seçin.',
  },
  MealImageAnalysisFailure.serviceUnavailable: {
    'en':
        'Meal-image analysis is temporarily unavailable. Try later or use food search.',
    'ar':
        'تحليل صور الوجبات غير متاح مؤقتًا. حاول لاحقًا أو استخدم البحث عن الطعام.',
    'fr':
        'L’analyse des photos de repas est temporairement indisponible. Réessayez plus tard ou utilisez la recherche alimentaire.',
    'es':
        'El análisis de imágenes no está disponible temporalmente. Inténtalo más tarde o usa la búsqueda.',
    'tr':
        'Yemek görseli analizi geçici olarak kullanılamıyor. Daha sonra deneyin veya yiyecek aramasını kullanın.',
  },
  MealImageAnalysisFailure.rateLimited: {
    'en': 'Too many image requests. Wait a moment, then try again.',
    'ar': 'تم إرسال طلبات صور كثيرة. انتظر قليلًا ثم حاول مجددًا.',
    'fr': 'Trop de demandes d’image. Patientez puis réessayez.',
    'es':
        'Hay demasiadas solicitudes de imágenes. Espera e inténtalo de nuevo.',
    'tr': 'Çok fazla görsel isteği gönderildi. Biraz bekleyip yeniden deneyin.',
  },
  MealImageAnalysisFailure.nonFoodOrUnrecognized: {
    'en':
        'No food could be identified reliably. Try another photo or add it manually.',
    'ar': 'تعذر التعرّف على طعام موثوق. جرّب صورة أخرى أو أضفه يدويًا.',
    'fr':
        'Aucun aliment n’a pu être identifié avec fiabilité. Essayez une autre photo ou ajoutez-le manuellement.',
    'es':
        'No se pudo identificar comida de forma fiable. Prueba otra foto o añádela manualmente.',
    'tr':
        'Yiyecek güvenilir biçimde tanımlanamadı. Başka bir fotoğraf deneyin veya elle ekleyin.',
  },
  MealImageAnalysisFailure.invalidResponse: {
    'en': 'The image result could not be trusted, so no food was added.',
    'ar': 'تعذر الوثوق بنتيجة الصورة، لذلك لم تتم إضافة أي طعام.',
    'fr':
        'Le résultat de l’image n’était pas fiable ; aucun aliment n’a été ajouté.',
    'es':
        'El resultado no era fiable, por lo que no se añadió ningún alimento.',
    'tr': 'Görsel sonucuna güvenilemediği için hiçbir yiyecek eklenmedi.',
  },
};

const _utf8Messages = <MealImageAnalysisFailure, Map<String, String>>{
  MealImageAnalysisFailure.notConfigured: {
    'en': 'Meal-image analysis is not configured for this build.',
    'ar': 'تحليل صور الوجبات غير مفعّل في هذا الإصدار.',
    'fr':
        'L’analyse des photos de repas n’est pas configurée dans cette version.',
    'es':
        'El análisis de imágenes de comidas no está configurado en esta versión.',
    'tr': 'Yemek görseli analizi bu sürüm için yapılandırılmamış.',
  },
  MealImageAnalysisFailure.authenticationRequired: {
    'en': 'Sign in before sending a meal image for secure analysis.',
    'ar': 'سجّل الدخول قبل إرسال صورة الوجبة للتحليل الآمن.',
    'fr':
        'Connectez-vous avant d’envoyer une photo de repas pour une analyse sécurisée.',
    'es':
        'Inicia sesión antes de enviar una imagen de comida para un análisis seguro.',
    'tr': 'Güvenli analiz için yemek görselini göndermeden önce oturum açın.',
  },
  MealImageAnalysisFailure.invalidImage: {
    'en': 'Choose a JPG, PNG, or WebP image up to 12 MB.',
    'ar': 'اختر صورة JPG أو PNG أو WebP بحجم لا يتجاوز 12 ميغابايت.',
    'fr': 'Choisissez une image JPG, PNG ou WebP de 12 Mo maximum.',
    'es': 'Elige una imagen JPG, PNG o WebP de hasta 12 MB.',
    'tr': 'En fazla 12 MB boyutunda JPG, PNG veya WebP seçin.',
  },
  MealImageAnalysisFailure.serviceUnavailable: {
    'en':
        'Meal-image analysis is temporarily unavailable. Try later or use food search.',
    'ar':
        'تحليل صور الوجبات غير متاح مؤقتًا. حاول لاحقًا أو استخدم البحث عن الطعام.',
    'fr':
        'L’analyse des photos de repas est temporairement indisponible. Réessayez plus tard ou utilisez la recherche alimentaire.',
    'es':
        'El análisis de imágenes no está disponible temporalmente. Inténtalo más tarde o usa la búsqueda.',
    'tr':
        'Yemek görseli analizi geçici olarak kullanılamıyor. Daha sonra deneyin veya yiyecek aramasını kullanın.',
  },
  MealImageAnalysisFailure.rateLimited: {
    'en': 'Too many image requests. Wait a moment, then try again.',
    'ar': 'تم إرسال طلبات صور كثيرة. انتظر قليلًا ثم حاول مجددًا.',
    'fr': 'Trop de demandes d’image. Patientez puis réessayez.',
    'es':
        'Hay demasiadas solicitudes de imágenes. Espera e inténtalo de nuevo.',
    'tr': 'Çok fazla görsel isteği gönderildi. Biraz bekleyip yeniden deneyin.',
  },
  MealImageAnalysisFailure.nonFoodOrUnrecognized: {
    'en':
        'No food could be identified reliably. Try another photo or add it manually.',
    'ar': 'تعذر التعرّف على طعام موثوق. جرّب صورة أخرى أو أضفه يدويًا.',
    'fr':
        'Aucun aliment n’a pu être identifié avec fiabilité. Essayez une autre photo ou ajoutez-le manuellement.',
    'es':
        'No se pudo identificar comida de forma fiable. Prueba otra foto o añádela manualmente.',
    'tr':
        'Yiyecek güvenilir biçimde tanımlanamadı. Başka bir fotoğraf deneyin veya elle ekleyin.',
  },
  MealImageAnalysisFailure.invalidResponse: {
    'en': 'The image result could not be trusted, so no food was added.',
    'ar': 'تعذر الوثوق بنتيجة الصورة، لذلك لم تتم إضافة أي طعام.',
    'fr':
        'Le résultat de l’image n’était pas fiable ; aucun aliment n’a été ajouté.',
    'es':
        'El resultado no era fiable, por lo que no se añadió ningún alimento.',
    'tr': 'Görsel sonucuna güvenilemediği için hiçbir yiyecek eklenmedi.',
  },
};

enum MealNutritionResolution { requiresVerifiedFoodMatch, verifiedFoodRecord }

class MealImageAlternative {
  const MealImageAlternative({required this.name, required this.confidence});
  final String name;
  final double confidence;
}

class MealImageCandidate {
  const MealImageCandidate({
    required this.name,
    required this.confidence,
    required this.evidence,
    required this.identificationProvider,
    required this.modelRevision,
    required this.nutritionResolution,
    this.amount,
    this.unit,
    this.alternatives = const [],
    this.uncertainty,
    this.warnings = const [],
    this.verifiedFoodRecordId,
  });
  final String name, evidence, identificationProvider, modelRevision;
  final double confidence;
  final MealNutritionResolution nutritionResolution;
  final double? amount;
  final String? unit, uncertainty, verifiedFoodRecordId;
  final List<MealImageAlternative> alternatives;
  final List<String> warnings;
  bool get requiresReview => true;
}

class MealImageAnalysis {
  const MealImageAnalysis({
    required this.candidates,
    required this.notice,
    required this.requestId,
  });
  final List<MealImageCandidate> candidates;
  final String notice, requestId;
  bool get requiresReview => true;
}

class MealImageGatewayResponse {
  const MealImageGatewayResponse({
    required this.statusCode,
    required this.body,
  });
  final int statusCode;
  final String body;
}

typedef MealImageGatewayPost =
    Future<MealImageGatewayResponse> Function({
      required Uri uri,
      required Map<String, String> headers,
      required String body,
    });
typedef MealImageAccessToken = String? Function();

Never _invalid() => throw const MealImageAnalysisException(
  MealImageAnalysisFailure.invalidResponse,
);
MealImageAnalysis parseMealImageResponse(
  String body, {
  String languageCode = 'en',
}) {
  Object? decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    _invalid();
  }
  if (decoded is! Map<String, dynamic> ||
      decoded['schema_version'] != 1 ||
      decoded['request_id'] is! String ||
      decoded['candidates'] is! List) {
    _invalid();
  }
  final requestId = (decoded['request_id'] as String).trim();
  final raw = decoded['candidates'] as List;
  if (requestId.isEmpty ||
      requestId.length > 128 ||
      raw.length > maximumMealImageCandidates) {
    _invalid();
  }
  final candidates = <MealImageCandidate>[];
  for (final value in raw) {
    if (value is! Map<String, dynamic>) _invalid();
    final name = (value['name'] as String?)?.trim() ?? '';
    final confidence = (value['confidence'] as num?)?.toDouble();
    final evidence = (value['evidence'] as String?)?.trim() ?? '';
    final provenance = value['provenance'];
    if (provenance is! Map<String, dynamic>) _invalid();
    final provider =
        (provenance['identification_provider'] as String?)?.trim() ?? '';
    final revision = (provenance['model_revision'] as String?)?.trim() ?? '';
    final resolution = switch (provenance['nutrition_resolution']) {
      'requires_verified_food_match' =>
        MealNutritionResolution.requiresVerifiedFoodMatch,
      'verified_food_record' => MealNutritionResolution.verifiedFoodRecord,
      _ => null,
    };
    final recordId = (provenance['verified_food_record_id'] as String?)?.trim();
    final amount = (value['amount'] as num?)?.toDouble();
    final unit = (value['unit'] as String?)?.trim();
    final uncertainty = (value['uncertainty'] as String?)?.trim();
    final rawAlternatives = value['alternatives'] as List? ?? const [];
    final rawWarnings = value['warnings'] as List? ?? const [];
    if (name.isEmpty ||
        name.length > 160 ||
        evidence.length > 500 ||
        confidence == null ||
        !confidence.isFinite ||
        confidence < 0 ||
        confidence > 1 ||
        provider.isEmpty ||
        provider.length > 80 ||
        revision.isEmpty ||
        revision.length > 80 ||
        resolution == null ||
        (amount != null &&
            (!amount.isFinite || amount <= 0 || amount > 100000)) ||
        (unit != null && (unit.isEmpty || unit.length > 24)) ||
        (uncertainty != null &&
            (uncertainty.isEmpty || uncertainty.length > 300)) ||
        rawAlternatives.length > 3 ||
        rawWarnings.length > 5 ||
        (resolution == MealNutritionResolution.verifiedFoodRecord &&
            (recordId == null || recordId.isEmpty))) {
      _invalid();
    }
    final alternatives = <MealImageAlternative>[];
    for (final alt in rawAlternatives) {
      if (alt is! Map<String, dynamic>) _invalid();
      final n = (alt['name'] as String?)?.trim() ?? '';
      final c = (alt['confidence'] as num?)?.toDouble();
      if (n.isEmpty ||
          n.length > 160 ||
          c == null ||
          !c.isFinite ||
          c < 0 ||
          c > 1) {
        _invalid();
      }
      alternatives.add(MealImageAlternative(name: n, confidence: c));
    }
    final warnings = <String>[];
    for (final warning in rawWarnings) {
      if (warning is! String ||
          warning.trim().isEmpty ||
          warning.trim().length > 240) {
        _invalid();
      }
      warnings.add(warning.trim());
    }
    candidates.add(
      MealImageCandidate(
        name: name,
        confidence: confidence,
        evidence: evidence,
        identificationProvider: provider,
        modelRevision: revision,
        nutritionResolution: resolution,
        amount: amount,
        unit: unit,
        alternatives: List.unmodifiable(alternatives),
        uncertainty: uncertainty,
        warnings: List.unmodifiable(warnings),
        verifiedFoodRecordId: recordId,
      ),
    );
  }
  final notice = (decoded['notice'] as String?)?.trim() ?? '';
  if (notice.length > 1000) _invalid();
  return MealImageAnalysis(
    candidates: List.unmodifiable(candidates),
    requestId: requestId,
    notice: notice.isEmpty
        ? (_utf8Notices[languageCode.toLowerCase()] ?? _utf8Notices['en']!)
        : notice,
  );
}

// ignore: unused_element
const _notices = <String, String>{
  'en':
      'Review every suggestion and serving before adding it. Nutrition comes only from a verified food record.',
  'ar':
      'راجع كل اقتراح وحصة قبل الإضافة. تأتي القيم الغذائية فقط من سجل طعام موثوق.',
  'fr':
      'Vérifiez chaque suggestion et portion avant l’ajout. Les valeurs nutritionnelles proviennent uniquement d’une fiche vérifiée.',
  'es':
      'Revisa cada sugerencia y porción antes de añadirla. La nutrición procede únicamente de un registro verificado.',
  'tr':
      'Eklemeden önce her öneriyi ve porsiyonu inceleyin. Besin değerleri yalnızca doğrulanmış bir kayıttan alınır.',
};
const _utf8Notices = <String, String>{
  'en':
      'Review every suggestion and serving before adding it. Nutrition comes only from a verified food record.',
  'ar':
      'راجع كل اقتراح وحصة قبل الإضافة. تأتي القيم الغذائية فقط من سجل طعام موثّق.',
  'fr':
      'Vérifiez chaque suggestion et portion avant l’ajout. Les valeurs nutritionnelles proviennent uniquement d’une fiche vérifiée.',
  'es':
      'Revisa cada sugerencia y porción antes de añadirla. La nutrición procede únicamente de un registro verificado.',
  'tr':
      'Eklemeden önce her öneriyi ve porsiyonu inceleyin. Besin değerleri yalnızca doğrulanmış bir kayıttan alınır.',
};
