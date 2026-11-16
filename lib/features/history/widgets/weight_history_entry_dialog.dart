part of '../history_page.dart';

String _historyWeightText(double value) =>
    value.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');

class _WeightTextEntryDialog extends StatefulWidget {
  const _WeightTextEntryDialog({
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.unit,
  });

  final double value;
  final double minimum;
  final double maximum;
  final String unit;

  @override
  State<_WeightTextEntryDialog> createState() => _WeightTextEntryDialogState();
}

class _WeightTextEntryDialogState extends State<_WeightTextEntryDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _text;
  bool _edited = false;

  @override
  void initState() {
    super.initState();
    final initial = _historyWeightText(widget.value);
    _text = TextEditingController(text: initial)
      ..selection = TextSelection(baseOffset: 0, extentOffset: initial.length);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  double? _parse(String raw) {
    final buffer = StringBuffer();
    for (final rune in raw.trim().runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.writeCharCode(0x30 + rune - 0x0660);
      } else if (rune >= 0x06f0 && rune <= 0x06f9) {
        buffer.writeCharCode(0x30 + rune - 0x06f0);
      } else {
        buffer.writeCharCode(rune == 0x066b || rune == 0x2c ? 0x2e : rune);
      }
    }
    final normalized = buffer.toString();
    if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(normalized)) return null;
    final value = double.tryParse(normalized);
    final displayedMinimum = double.parse(_historyWeightText(widget.minimum));
    final displayedMaximum = double.parse(_historyWeightText(widget.maximum));
    if (value == null ||
        !value.isFinite ||
        value < displayedMinimum ||
        value > displayedMaximum) {
      return null;
    }
    if (!_edited &&
        widget.value.isFinite &&
        widget.value >= widget.minimum &&
        widget.value <= widget.maximum) {
      return widget.value;
    }
    // Unit conversion has more precision than the visible two-decimal input.
    // A displayed endpoint such as44.09lb represents the exact20kg boundary;
    // keep accepted UI bounds consistent without saving an out-of-range kg.
    return value.clamp(widget.minimum, widget.maximum).toDouble();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.of(context).pop(_parse(_text.text)!);
    }
  }

  @override
  Widget build(BuildContext context) => BilPearlMaterialAlertDialog(
    title: Text(context.strings.text('Enter weight')),
    content: Form(
      key: _form,
      child: TextFormField(
        key: const Key('weight-history-precise-input'),
        controller: _text,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        inputFormatters: [LengthLimitingTextInputFormatter(12)],
        decoration: InputDecoration(
          labelText: context.strings.text('Weight'),
          suffixText: widget.unit,
          helperText:
              '${_historyWeightText(widget.minimum)} – '
              '${_historyWeightText(widget.maximum)} ${widget.unit}',
        ),
        validator: (raw) => _parse(raw ?? '') == null
            ? context.strings.text('Enter a valid weight.')
            : null,
        onChanged: (_) => _edited = true,
        onFieldSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.strings.text('Cancel')),
      ),
      FilledButton(
        key: const Key('weight-history-precise-apply'),
        onPressed: _submit,
        child: Text(context.strings.text('Apply')),
      ),
    ],
  );
}

const _weightConditionKeys = [
  'morning',
  'afterFood',
  'afterBathroom',
  'beforeFoodDrink',
  'differentConditions',
  'unspecified',
];

String _weightConditionLabel(BuildContext context, String value) {
  final locale = Localizations.localeOf(context);
  final labels =
      _weightConditionCopy[locale.toLanguageTag()] ??
      _weightConditionCopy[locale.languageCode] ??
      _weightConditionCopy['en']!;
  final index = _weightConditionKeys.indexOf(value);
  return labels[index < 0 ? 5 : index];
}

const _weightConditionCopy = <String, List<String>>{
  'en': [
    'Morning',
    'After eating',
    'After using the bathroom',
    'Before food or drink',
    'Different conditions',
    'Not specified',
  ],
  'ar': [
    'صباحًا',
    'بعد الطعام',
    'بعد استخدام الحمام',
    'قبل الطعام أو الشراب',
    'ظروف مختلفة',
    'غير محدد',
  ],
  'fr': [
    'Le matin',
    'Après un repas',
    'Après être allé aux toilettes',
    'Avant de manger ou de boire',
    'Conditions différentes',
    'Non précisé',
  ],
  'es': [
    'Por la mañana',
    'Después de comer',
    'Después de ir al baño',
    'Antes de comer o beber',
    'Condiciones diferentes',
    'Sin especificar',
  ],
  'tr': [
    'Sabah',
    'Yemekten sonra',
    'Tuvaletten sonra',
    'Yemek veya içecekten önce',
    'Farklı koşullar',
    'Belirtilmedi',
  ],
  'de': [
    'Morgens',
    'Nach dem Essen',
    'Nach dem Toilettengang',
    'Vor dem Essen oder Trinken',
    'Andere Bedingungen',
    'Nicht angegeben',
  ],
  'it': [
    'Al mattino',
    'Dopo aver mangiato',
    'Dopo essere andati in bagno',
    'Prima di mangiare o bere',
    'Condizioni diverse',
    'Non specificato',
  ],
  'pt-BR': [
    'De manhã',
    'Depois de comer',
    'Depois de usar o banheiro',
    'Antes de comer ou beber',
    'Condições diferentes',
    'Não especificado',
  ],
  'pt-PT': [
    'De manhã',
    'Depois de comer',
    'Depois de ir à casa de banho',
    'Antes de comer ou beber',
    'Condições diferentes',
    'Não especificado',
  ],
  'ur': [
    'صبح',
    'کھانے کے بعد',
    'بیت الخلا کے بعد',
    'کھانے یا پینے سے پہلے',
    'مختلف حالات',
    'متعین نہیں',
  ],
  'fa': [
    'صبح',
    'پس از غذا',
    'پس از استفاده از دستشویی',
    'پیش از خوردن یا نوشیدن',
    'شرایط متفاوت',
    'مشخص نشده',
  ],
  'hi': [
    'सुबह',
    'खाने के बाद',
    'शौचालय जाने के बाद',
    'खाने या पीने से पहले',
    'अलग परिस्थितियाँ',
    'निर्दिष्ट नहीं',
  ],
  'id': [
    'Pagi hari',
    'Setelah makan',
    'Setelah ke toilet',
    'Sebelum makan atau minum',
    'Kondisi berbeda',
    'Tidak ditentukan',
  ],
  'ms': [
    'Waktu pagi',
    'Selepas makan',
    'Selepas ke tandas',
    'Sebelum makan atau minum',
    'Keadaan berbeza',
    'Tidak dinyatakan',
  ],
  'ja': ['朝', '食後', 'トイレの後', '飲食の前', '異なる条件', '未指定'],
  'ko': ['아침', '식후', '화장실 이용 후', '먹거나 마시기 전', '다른 조건', '지정되지 않음'],
  'zh-Hans': ['早晨', '饭后', '如厕后', '进食或饮水前', '不同条件', '未指定'],
  'zh-Hant': ['早晨', '飯後', '如廁後', '進食或飲水前', '不同條件', '未指定'],
  'ru': [
    'Утром',
    'После еды',
    'После туалета',
    'До еды или питья',
    'Другие условия',
    'Не указано',
  ],
  'bn': [
    'সকালে',
    'খাওয়ার পরে',
    'শৌচাগার ব্যবহারের পরে',
    'খাওয়া বা পান করার আগে',
    'ভিন্ন পরিস্থিতি',
    'নির্দিষ্ট নয়',
  ],
  'vi': [
    'Buổi sáng',
    'Sau khi ăn',
    'Sau khi đi vệ sinh',
    'Trước khi ăn hoặc uống',
    'Điều kiện khác',
    'Chưa xác định',
  ],
  'th': [
    'ตอนเช้า',
    'หลังรับประทานอาหาร',
    'หลังเข้าห้องน้ำ',
    'ก่อนรับประทานอาหารหรือดื่ม',
    'เงื่อนไขต่างกัน',
    'ไม่ระบุ',
  ],
  'pl': [
    'Rano',
    'Po jedzeniu',
    'Po skorzystaniu z toalety',
    'Przed jedzeniem lub piciem',
    'Inne warunki',
    'Nie określono',
  ],
  'nl': [
    'In de ochtend',
    'Na het eten',
    'Na toiletbezoek',
    'Voor eten of drinken',
    'Andere omstandigheden',
    'Niet opgegeven',
  ],
  'uk': [
    'Вранці',
    'Після їжі',
    'Після туалету',
    'До їжі або пиття',
    'Інші умови',
    'Не вказано',
  ],
};
