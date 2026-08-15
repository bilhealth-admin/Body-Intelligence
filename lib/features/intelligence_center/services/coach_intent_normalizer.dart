enum CoachInputChannel { text, voice }

class NormalizedCoachInput {
  const NormalizedCoachInput({
    required this.original,
    required this.normalized,
    required this.locale,
    required this.channel,
  });

  final String original;
  final String normalized;
  final String locale;
  final CoachInputChannel channel;
}

/// Provider-neutral syntax normalization shared by typed and spoken input.
/// Authorization, entity resolution and execution remain downstream.
class CoachIntentNormalizer {
  const CoachIntentNormalizer();

  NormalizedCoachInput normalize({
    required String text,
    required String locale,
    required CoachInputChannel channel,
  }) {
    var value = text.trim().toLowerCase();
    const digits = <String, String>{
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
      '۰': '0',
      '۱': '1',
      '۲': '2',
      '۳': '3',
      '۴': '4',
      '۵': '5',
      '۶': '6',
      '۷': '7',
      '۸': '8',
      '۹': '9',
    };
    for (final entry in digits.entries) {
      value = value.replaceAll(entry.key, entry.value);
    }
    value = value.replaceAll('٫', '.').replaceAll('،', ' ');
    value = value.replaceAllMapped(
      RegExp(r'(?<!\d)(\d{1,3})\s*(?:ونص|و نص)(?!\p{L})', unicode: true),
      (match) => '${match.group(1)}.5',
    );
    value = _appendCanonicalMarker(value, const [
      'وزني',
      'وزن',
      'كيلو',
      'كغ',
      'كلغ',
      'دخللي وزني',
      'سجل وزني',
      'سجّل وزني',
      'حط وزني',
      'دير وزني',
      'اكتب وزني',
      'حق يوم',
    ], 'weight');
    value = _appendCanonicalMarker(value, const [
      'ميه',
      'مياه',
      'موية',
      'ماي',
      'ماء',
      'اشرب',
      'سجل ماء',
      'سجّل ماء',
      'دير الما',
      'شربت',
    ], 'water');
    value = _appendCanonicalMarker(value, const [
      'امسح حسابي',
      'احذف حسابي',
      'حذف حسابي',
      'سكر حسابي',
    ], 'delete account');
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return NormalizedCoachInput(
      original: text,
      normalized: value,
      locale: locale,
      channel: channel,
    );
  }

  String _appendCanonicalMarker(
    String value,
    List<String> variants,
    String marker,
  ) {
    if (value.contains(marker) || !variants.any(value.contains)) return value;
    return '$value $marker';
  }
}
