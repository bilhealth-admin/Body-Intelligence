import '../domain/intelligence_action.dart';

/// Keeps model wording separate from effects performed by the Flutter client.
/// A proposed navigation is not a receipt that navigation already happened.
class CoachActionPresentationPolicy {
  const CoachActionPresentationPolicy();

  bool isNavigation(IntelligenceAction action) {
    if (action.requiresConfirmation) return false;
    return switch (action.type) {
      IntelligenceActionType.navigate ||
      IntelligenceActionType.openDailyLog ||
      IntelligenceActionType.reviewMeal ||
      IntelligenceActionType.reviewWorkout ||
      IntelligenceActionType.openPlan ||
      IntelligenceActionType.openReport => true,
      IntelligenceActionType.addWeight => action.payload['weightKg'] == null,
      _ => false,
    };
  }

  bool isDirectNavigationRequest(String input, IntelligenceAction action) {
    if (!isNavigation(action)) return false;
    final value = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\u0640\u064b-\u065f\u0670\u06d6-\u06ed]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا');
    return _directOpenMarkers.any(value.contains);
  }

  bool isContextualOpenFollowUp(String input) {
    final value = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .trim();
    return _contextualOpenPhrases.contains(value);
  }

  static const _directOpenMarkers = <String>[
    'open',
    'show',
    'view',
    'take me to',
    'go to',
    'افتح',
    'اعرض',
    'استعرض',
    'اذهب',
    'وديني',
    'ouvrir',
    'ouvre',
    'montre',
    'affiche',
    'abre',
    'muestra',
    'aç',
    'göster',
    'öffne',
    'zeig',
    'apri',
    'mostra',
    'abrir',
    'کھول',
    'دکھا',
    'باز کن',
    'نشان بده',
    'खोल',
    'दिखा',
    'buka',
    'tampilkan',
    'tunjukkan',
    '開いて',
    '見せて',
    '열어',
    '보여',
    '打开',
    '显示',
    '開啟',
    '顯示',
    'открой',
    'покажи',
    'খুল',
    'দেখা',
    'mở',
    'hiển thị',
    'เปิด',
    'แสดง',
    'otwórz',
    'pokaż',
    'toon',
    'відкрий',
  ];

  static const _contextualOpenPhrases = <String>{
    'open it',
    'show it',
    'take me there',
    'go there',
    'افتحها',
    'افتحه',
    'اعرضها',
    'اعرضه',
    'وديني لها',
    'وديني له',
    'اذهب اليها',
    'اذهب اليه',
  };
}
