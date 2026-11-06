/// Pure question-shape admission shared by semantic intent and local catalogs.
/// It neither chooses an action nor invokes a model or data source.
bool coachRequestsReasonedOrFormattedAnswer(String question) {
  final text = _normalizeQuestionPurpose(question);
  if (RegExp(
    r'\b(?:compare|comparing|versus|vs)\b|'
    r'\bcomparison\s+(?:of|between|with)\b|'
    r'\b(?:want|need|show|give|provide|make|write)\s+'
    r'(?:(?:me|us|a|the|brief|short)\s+){0,3}comparison\b|'
    r'\bdifferences?\b|\bdifferent\s+from\b|'
    r'قارن|يقارن|الفرق|الفروق|(?:اعرض|اكتب|قدم|اريد)\s+(?:لي\s+)?مقارنه',
  ).hasMatch(text)) {
    return true;
  }
  final layout = RegExp(
    r'\bmarkdown\b|'
    r'\b(?:add|show|give|write|create|format|use)\s+'
    r'(?:(?:me|a|an|the|one|two|three|four|\d+|short|brief|bold)\s+){0,5}'
    r'(?:headings?|bullets?|bullet points?|bold text)\b|'
    r'(?:اضف|اعرض|اكتب|استخدم)\s+(?:لي\s+)?(?:عنوان|عناوين|نقطتين|نقاط|نصا? عريضا?)|'
    r'\b(?:in|into|as)\s+(?:an?\s+)?table\b|'
    r'\b(?:show|make|create|write|format|present|display)\s+'
    r'(?:me\s+)?(?:(?:a|an|the)\s+)?'
    r'(?:(?:one|two|three|four|\d+)[ -]rows?\s+)?table\b|'
    r'\btable\s+(?:with|of)\s+(?:one|two|three|four|\d+)\s+(?:rows?|columns?)\b|'
    r'\b(?:in|into|using|as|with)\s+(?:(?:one|two|three|four|\d+)\s+)?columns?\b|'
    r'\brows?\b[^.!?]*\bcolumns?\b|\bcolumns?\b[^.!?]*\brows?\b|'
    r'(?:في\s+جدول|بجدول|كجدول|'
    r'(?:اعرض|اكتب|انشئ|وريني|قدم)\s+(?:لي\s+)?جدول)|'
    r'(?:صفين|صفوف|صفان|سطور|اسطر)[^.!?؛؟]*(?:عمودين|عمودان|اعمده)|'
    r'(?:عمودين|عمودان|اعمده)[^.!?؛؟]*(?:صفين|صفوف|صفان|سطور|اسطر)',
  ).hasMatch(text);
  if (layout) return true;
  // A requested verified demonstration may use "شرح" or "explain". An
  // explicit comparison/layout still wins before this video exception.
  if (RegExp(
    r'\b(?:video|videos|demonstration|demo|tutorial)\b|فيديو|فديو|مقطع',
  ).hasMatch(text)) {
    return false;
  }
  // Translation is an answer operation, even when phrased as "Add a brief
  // Arabic translation". A translated video lookup keeps its catalog owner.
  if (RegExp(
    r'\b(?:translate|translation|translations|summari[sz]e|summary|rewrite|paraphrase)\b|'
    r'ترجم|ترجمه|لخص|تلخيص|اعد صياغه',
  ).hasMatch(text)) {
    return true;
  }
  return RegExp(
    r'\b(?:explain|define|definition)\b|\bwhat\b[^.!?]{0,120}\bmean\b|'
    r'ما\s+معني|ماذا\s+يعني|اشرح|شرح|وضح|تعريف',
  ).hasMatch(text);
}

String _normalizeQuestionPurpose(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه')
    .trim();
