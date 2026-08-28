enum CoachSpeechPlan { directAnswer, dataLookup, goalAnalysis, extendedAnswer }

class CoachSpeechPolicy {
  const CoachSpeechPolicy();

  CoachSpeechPlan planFor(String question) {
    final normalized = _normalize(question);
    if (_containsAny(normalized, _goalAnalysisMarkers)) {
      return CoachSpeechPlan.goalAnalysis;
    }
    if (isWeightLookup(question)) {
      return CoachSpeechPlan.dataLookup;
    }
    if (isSleepQuestion(question)) return CoachSpeechPlan.directAnswer;
    if (_containsAny(normalized, _quickAnswerMarkers) &&
        normalized.trim().length <= 120) {
      return CoachSpeechPlan.directAnswer;
    }
    if (normalized.trim().length <= 42 &&
        normalized.trim().split(RegExp(r'\s+')).length <= 8) {
      return CoachSpeechPlan.directAnswer;
    }
    return CoachSpeechPlan.extendedAnswer;
  }

  bool isWeightLookup(String question) {
    final normalized = _normalize(question).trim();
    if (_containsAny(normalized, _goalAnalysisMarkers)) return false;
    return _weightLookupPhrases.any(normalized.contains) ||
        _standaloneWeightTerms.contains(normalized);
  }

  bool isSleepQuestion(String question) {
    final normalized = _normalize(question).trim();
    final words = normalized.split(RegExp(r'\s+')).toSet();
    return _sleepMarkers.any((marker) {
      if (marker == 'son' || marker == 'sen') return words.contains(marker);
      return normalized.contains(marker);
    });
  }

  bool canSpeakWithinTenSeconds(String value) {
    final plain = value
        .replaceAll(RegExp(r'[`*_#>]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (plain.isEmpty || plain.length > 180) return false;
    final words = RegExp(
      r'[\p{L}\p{M}\p{N}]+',
      unicode: true,
    ).allMatches(plain).length;
    final cjk = RegExp(
      r'[\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]',
    ).allMatches(plain).length;
    if (cjk > 0) return cjk <= 48 && plain.length <= 90;
    return words <= 24;
  }

  bool _containsAny(String value, List<String> markers) =>
      markers.any(value.contains);

  String _normalize(String value) => value.toLowerCase().replaceAll(
    RegExp(r'[^\p{L}\p{M}\p{N}\s]', unicode: true),
    ' ',
  );

  static const _goalAnalysisMarkers = <String>[
    'goal',
    'target',
    'plateau',
    'stable',
    'stagn',
    'why',
    'history',
    'trend',
    'change',
    'lose',
    'loss',
    'gain',
    'average',
    'compare',
    'ideal',
    'healthy',
    'analy',
    'recommend',
    'timeline',
    'diet',
    'workout',
    'exercise',
    'هدف',
    'ثبات',
    'ثابت',
    'لماذا',
    'تاريخ',
    'تغير',
    'خسر',
    'نقص',
    'زيادة',
    'متوسط',
    'قارن',
    'مثالي',
    'حلل',
    'توصي',
    'حمية',
    'رياض',
    'objectif',
    'recommand',
    'régime',
    'entraînement',
    'historique',
    'tendance',
    'perdre',
    'moyenne',
    'pourquoi',
    'idéal',
    'meta',
    'meseta',
    'estanc',
    'recom',
    'dieta',
    'ejercicio',
    'historial',
    'tendencia',
    'perder',
    'promedio',
    'por qué',
    'ideal',
    'hedef',
    'öner',
    'diyet',
    'antrenman',
    'ziel',
    'empfehl',
    'diät',
    'training',
    'obiettivo',
    'consigl',
    'dieta',
    'treino',
    'objetivo',
    'cel',
    'zalec',
    'dieet',
    'doel',
    'рекоменд',
    'цель',
    'диет',
    'упражнен',
    'анализ',
    'мета',
    'дієт',
    'вправ',
    'аналіз',
    'مقصد',
    'ہدف',
    'غذا',
    'ورزش',
    'تجزیہ',
    'سفارش',
    'هدف',
    'رژیم',
    'تحلیل',
    'توصیه',
    'लक्ष्य',
    'आहार',
    'व्यायाम',
    'विश्लेषण',
    'सिफारिश',
    'tujuan',
    'olahraga',
    'analisis',
    'rekomendasi',
    'matlamat',
    'senaman',
    'cadangan',
    '目標',
    '食事',
    '運動',
    '分析',
    '推奨',
    '목표',
    '식단',
    '운동',
    '분석',
    '추천',
    '目标',
    '饮食',
    '运动',
    '建议',
    '推荐',
    '飲食',
    '建議',
    '推薦',
    'লক্ষ্য',
    'খাদ্য',
    'ব্যায়াম',
    'বিশ্লেষণ',
    'সুপারিশ',
    'mục tiêu',
    'chế độ ăn',
    'tập luyện',
    'phân tích',
    'khuyến nghị',
    'เป้าหมาย',
    'อาหาร',
    'ออกกำลัง',
    'วิเคราะห์',
    'แนะนำ',
  ];

  static const _weightLookupPhrases = <String>[
    'my weight',
    'current weight',
    'latest weight',
    'recorded weight',
    'what do i weigh',
    'how much do i weigh',
    'كم وزني',
    'ما وزني',
    'وزني كم',
    'وزني الحالي',
    'آخر وزن',
    'الوزن المسجل',
    'mon poids',
    'poids actuel',
    'dernier poids',
    'combien je pèse',
    'mi peso',
    'peso actual',
    'último peso',
    'cuánto peso',
    'kilom kaç',
    'güncel kilom',
    'son kilom',
    'mevcut kilom',
    'mein gewicht',
    'aktuelles gewicht',
    'letztes gewicht',
    'wie viel wiege',
    'il mio peso',
    'peso attuale',
    'ultimo peso',
    'quanto peso',
    'meu peso',
    'peso atual',
    'میرا وزن',
    'وزن کتنا',
    'وزنم',
    'وزن من',
    'मेरा वजन',
    'berat saya',
    '私の体重',
    '現在の体重',
    '내 체중',
    '현재 체중',
    '我的体重',
    '当前体重',
    '我的體重',
    '當前體重',
    'мой вес',
    'текущий вес',
    'последний вес',
    'сколько я вешу',
    'আমার ওজন',
    'cân nặng của tôi',
    'cân nặng hiện tại',
    'น้ำหนักของฉัน',
    'น้ำหนักปัจจุบัน',
    'moja waga',
    'aktualna waga',
    'ile ważę',
    'mijn gewicht',
    'huidig gewicht',
    'hoeveel weeg ik',
    'моя вага',
    'поточна вага',
    'скільки я важу',
  ];

  static const _standaloneWeightTerms = <String>{
    'weight',
    'وزني',
    'poids',
    'peso',
    'kilom',
    'gewicht',
    'وزنم',
    'वजन',
    'berat',
    '体重',
    '體重',
    '체중',
    'вес',
    'ওজন',
    'น้ำหนัก',
    'waga',
    'вага',
  };

  static const _quickAnswerMarkers = <String>[
    'sleep',
    'nap',
    'نوم',
    'أنام',
    'ماء',
    'شرب',
    'water',
    'hydrate',
    'sommeil',
    'dormir',
    'sueño',
    'dormir',
    'uyku',
    'schlaf',
    'sonno',
    'sono',
    'نیند',
    'خواب',
    'नींद',
    'tidur',
    '睡眠',
    '睡覺',
    'сон',
    'ঘুম',
    'นอน',
    'sen',
    'slaap',
    'спати',
    'hello',
    'hi',
    'مرحبا',
  ];

  static const _sleepMarkers = <String>[
    'sleep',
    'nap',
    'نوم',
    'أنام',
    'نام',
    'sommeil',
    'dormir',
    'sueño',
    'uyku',
    'uyum',
    'schlaf',
    'sonno',
    'sono',
    'نیند',
    'سونا',
    'خواب',
    'नींद',
    'सोना',
    'tidur',
    '睡眠',
    '寝る',
    '수면',
    '잠',
    '睡觉',
    '睡覺',
    'сон',
    'спать',
    'ঘুম',
    'ngủ',
    'giấc ngủ',
    'นอน',
    'การนอน',
    'sen',
    'spać',
    'slaap',
    'slapen',
    'спати',
  ];
}
