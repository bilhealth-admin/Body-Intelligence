/// Model prose is never proof of a mutation. Native receipt messages take a
/// separate path and do not pass through this model-output boundary.
bool modelClaimsUnverifiedAction(String text) {
  final normalized = text.toLowerCase().replaceAll(RegExp('[أإآ]'), 'ا');
  return RegExp(
    r"\b(?:i|we|bil)(?:'ve| have| has)?\s+(?:successfully\s+)?(?:logged|recorded|saved|activated|deleted|updated|completed|drafted|created|initiated|prepared)\s+(?:your|the|this|that|it|a)\b|"
    r'(?:^|[.!؟\n]\s*)(?:لقد\s+)?(?:سجلت|حفظت|فعلت|اكملت|حذفت|عدلت|انشات|جهزت|اعددت)\s+(?:لك|ال|وزن|وجبة|تمرين|خط|مسودة)|'
    r'(?:^|[.!؟\n]\s*)تم\s+(?:تسجيل|حفظ|تفعيل|حذف|تحديث|اكمال|انشاء|اعداد)\s+(?:ال|وزن|وجبة|تمرين|خط|مسودة)',
    unicode: true,
  ).hasMatch(normalized);
}
