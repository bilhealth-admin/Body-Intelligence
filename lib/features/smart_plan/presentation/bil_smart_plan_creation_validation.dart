part of 'bil_smart_plan_page.dart';

Widget _planPrepareLabel(BuildContext context, {required bool checking}) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    SizedBox.square(
      dimension: 24,
      child: checking
          ? BilFeatureWelcomeStatus(
              label: _smartPlanText(
                context,
                'Checking recipes',
                'جارٍ التحقق من الوصفات',
              ),
            )
          : null,
    ),
    const SizedBox(width: 8),
    Flexible(
      child: Text(_smartPlanText(context, 'Prepare a draft', 'تجهيز المسودة')),
    ),
    const SizedBox(width: 32),
  ],
);

String _planStyleLabel(BuildContext context, MealPlanDiet style) =>
    switch (style) {
      MealPlanDiet.balanced => _smartPlanText(
        context,
        'Balanced recipes',
        'وجبات متوازنة',
      ),
      MealPlanDiet.vegetarian => _smartPlanText(
        context,
        'Vegetarian recipes',
        'وجبات نباتية',
      ),
      MealPlanDiet.highProtein => _smartPlanText(
        context,
        'High-protein recipes',
        'وجبات عالية البروتين',
      ),
    };

Widget _planRecipeGuidance(
  BuildContext context,
  BilPlanRecipeChoices choices,
  ValueChanged<MealPlanDiet?> choose,
) {
  String t(String en, String ar) => _smartPlanText(context, en, ar);
  final missing = choices.missing.map(
    (slot) => switch (slot) {
      BilPlanMealSlot.breakfast => t('Breakfast', 'الفطور'),
      BilPlanMealSlot.lunch => t('Lunch', 'الغداء'),
      BilPlanMealSlot.dinner => t('Dinner', 'العشاء'),
    },
  );
  return Column(
    key: const ValueKey('bil-smart-plan-recipe-guidance'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        liveRegion: true,
        child: Text(
          "${t('No matching recipes.', 'لا توجد وصفات مطابقة.')} ${missing.join(' · ')}",
        ),
      ),
      Wrap(
        children: [
          for (final style in choices.alternatives)
            TextButton(
              onPressed: () => choose(style),
              child: Text(_planStyleLabel(context, style)),
            ),
          if (choices.alternatives.isEmpty)
            TextButton(
              onPressed: () => choose(null),
              child: Text(t('Training only', 'تدريب فقط')),
            ),
        ],
      ),
    ],
  );
}

const _planRequiredFields = [
  'horizon',
  'focus',
  'environment',
  'experience',
  'minutes',
  'sessions',
  'equipment',
  'diet',
  'confirmation',
  'symptoms',
  'medical',
];

final class _MissingPlanChoice {
  const _MissingPlanChoice(this.field, this.label);
  final String field, label;
}

Map<String, String> _planRequiredLabels(BuildContext context) {
  String t(String en, String ar) => _smartPlanText(context, en, ar);
  return {
    'horizon': t('Duration', 'المدة'),
    'focus': t('Plan focus', 'تركيز الخطة'),
    'environment': t('Training environment', 'مكان التدريب'),
    'experience': t('Training experience', 'الخبرة التدريبية'),
    'minutes': t('Your session time budget: ', 'الوقت المتاح للجلسة: ').trim(),
    'sessions': t('Sessions per week: ', 'جلسات التدريب أسبوعيًا: ').trim(),
    'equipment': t('Available equipment', 'المعدات المتاحة'),
    'diet': t('Recipe style', 'نمط الوجبات'),
    'confirmation': t(
      'I am 18 or older and reviewed my allergies, dietary restrictions and training availability.',
      'عمري 18 عامًا أو أكثر وراجعت قيود الطعام والحساسية وتوفر التدريب.',
    ),
    'symptoms': t(
      'I have concerning symptoms or an injury affecting exercise.',
      'لدي أعراض مقلقة أو إصابة تؤثر على التمرين.',
    ),
    'medical': t(
      'I am pregnant, postpartum, or my diet or training requires clinician supervision.',
      'أنا حامل أو بعد الولادة، أو يحتاج غذائي أو تدريبي متابعة طبية.',
    ),
  };
}

Future<String?> _showPlanChoiceReview(
  BuildContext context,
  List<_MissingPlanChoice> choices, {
  required bool medical,
  required bool Function() isCurrent,
}) {
  // Capture text before opening: the parent owner visit may close this route
  // while a later dialog frame is still being built.
  final title = medical
      ? _smartPlanText(context, 'Personal plan', 'خطة شخصية')
      : _planValidationCopy(context, 0);
  final message = medical
      ? _smartPlanText(
          context,
          'A qualified professional should review your needs before a personal plan is prepared.',
          'راجع مختصًا لتقييم احتياجاتك قبل إعداد خطة شخصية.',
        )
      : null;
  final cancel = _smartPlanText(context, 'Cancel', 'إلغاء');
  return showDialog<String>(
    context: context,
    builder: (dialog) => BilPearlMaterialAlertDialog(
      key: ValueKey(
        medical
            ? 'bil-smart-plan-medical-review'
            : 'bil-smart-plan-required-choices',
      ),
      scrollable: true,
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(message),
            ),
          for (final choice in choices)
            ListTile(
              key: ValueKey('bil-smart-plan-missing-${choice.field}'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.radio_button_unchecked_rounded),
              title: Text(choice.label),
              trailing: const BilCrystalArrow(
                extent: 30,
                child: Icon(Icons.arrow_forward_rounded),
              ),
              onTap: () {
                if (dialog.mounted && isCurrent()) {
                  Navigator.pop(dialog, choice.field);
                }
              },
            ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('bil-smart-plan-validation-cancel'),
          onPressed: () {
            if (dialog.mounted) Navigator.pop(dialog);
          },
          child: Text(cancel),
        ),
      ],
    ),
  );
}

String _planValidationCopy(BuildContext context, int index) =>
    (_planValidationRows[BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    )] ??
    _planValidationRows['en']!)[index];
const _planValidationRows = <String, List<String>>{
  "en": ["Complete required details", "Select", "Yes", "No"],
  "ar": ["أكمل الاختيارات المطلوبة", "اختر", "نعم", "لا"],
  "fr": ["Complétez les informations requises", "Sélectionner", "Oui", "Non"],
  "es": ["Completa los datos necesarios", "Seleccionar", "Sí", "No"],
  "tr": ["Gerekli bilgileri tamamlayın", "Seçin", "Evet", "Hayır"],
  "de": ["Erforderliche Angaben ergänzen", "Auswählen", "Ja", "Nein"],
  "it": ["Completa i dati richiesti", "Seleziona", "Sì", "No"],
  "pt-BR": ["Preencha os dados obrigatórios", "Selecionar", "Sim", "Não"],
  "pt-PT": ["Preenche os dados obrigatórios", "Selecionar", "Sim", "Não"],
  "ur": ["مطلوبہ معلومات مکمل کریں", "منتخب کریں", "ہاں", "نہیں"],
  "fa": ["اطلاعات ضروری را تکمیل کنید", "انتخاب کنید", "بله", "خیر"],
  "hi": ["ज़रूरी जानकारी पूरी करें", "चुनें", "हाँ", "नहीं"],
  "id": ["Lengkapi informasi yang diperlukan", "Pilih", "Ya", "Tidak"],
  "ms": ["Lengkapkan maklumat yang diperlukan", "Pilih", "Ya", "Tidak"],
  "ja": ["必要な項目を入力してください", "選択", "はい", "いいえ"],
  "ko": ["필수 항목을 입력하세요", "선택", "예", "아니요"],
  "zh-Hans": ["请填写必填信息", "选择", "是", "否"],
  "zh-Hant": ["請填寫必填資訊", "選擇", "是", "否"],
  "ru": ["Заполните обязательные поля", "Выбрать", "Да", "Нет"],
  "bn": ["প্রয়োজনীয় তথ্য পূরণ করুন", "নির্বাচন করুন", "হ্যাঁ", "না"],
  "vi": ["Điền thông tin bắt buộc", "Chọn", "Có", "Không"],
  "th": ["กรอกข้อมูลที่จำเป็นให้ครบ", "เลือก", "ใช่", "ไม่ใช่"],
  "pl": ["Uzupełnij wymagane informacje", "Wybierz", "Tak", "Nie"],
  "nl": ["Vul de verplichte gegevens in", "Selecteren", "Ja", "Nee"],
  "uk": ["Заповніть обов’язкові поля", "Вибрати", "Так", "Ні"],
};

// Exact move of the existing shared protected-write predicate.
extension _BilSmartPlanAccessGuard on _BilSmartPlanPageState {
  String? get _owner => ref.read(verifiedEntitlementOwnerIdProvider);

  BilSmartPlanRepository get _repository {
    final epoch = _ownerEpoch;
    return BilSmartPlanRepository(
      preferences: ref.read(preferencesRepositoryProvider),
      currentOwnerId: () => mounted && epoch == _ownerEpoch ? _owner : null,
    );
  }

  void _checkAccess() {
    if (_unverifiedPlanReadOnly) {
      throw StateError('smart_plan_catalog_unavailable');
    }
    if (widget.privacyOnly) {
      throw StateError('smart_plan_verified_subscription_required');
    }
    widget.toolRequest?.checkAccess?.call();
    final access = ref.read(verifiedSubscriptionAccessProvider);
    if (!mounted ||
        _owner == null ||
        access.isLoading ||
        access.hasError ||
        access.value?.authority != EntitlementAuthority.verifiedServer ||
        access.value?.plan == CommercePlan.free) {
      throw StateError('smart_plan_verified_subscription_required');
    }
  }
}
