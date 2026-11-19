part of 'meal_vision_premium_review.dart';

class _VisionMissingField {
  const _VisionMissingField(this.id, this.label);
  final String id, label;
}

/// Owns focus and the authenticated visit, never nutrition or write authority.
class _VisionRequiredFields {
  _VisionRequiredFields() {
    if (!AppEnvironment.supabaseRuntimeReady) return;
    _auth = Supabase.instance.client.auth;
    _owner = _auth!.currentUser?.id;
    var delivered = _owner;
    _subscription = _auth!.onAuthStateChange.listen((state) {
      final next = state.session?.user.id;
      if (next != delivered) _retired = true;
      delivered = next;
    }, onError: (Object _, StackTrace _) => _retired = true);
  }
  GoTrueClient? _auth;
  String? _owner;
  StreamSubscription<AuthState>? _subscription;
  final _nodes = <String, FocusNode>{};
  bool _retired = false, _reviewing = false;

  bool get current =>
      !_retired &&
      (_auth == null
          ? !AppEnvironment.supabaseRuntimeReady ||
                Supabase.instance.client.auth.currentUser == null
          : _auth!.currentUser?.id == _owner);
  FocusNode node(String id) =>
      _nodes.putIfAbsent(id, () => FocusNode(debugLabel: 'vision-$id'));

  Future<void> review(
    BuildContext context,
    List<_VisionMissingField> missing, {
    required bool Function() alive,
  }) async {
    if (_reviewing || !current || !alive() || missing.isEmpty) return;
    final parent = ModalRoute.of(context);
    final title = _visionRequiredCopy(context, 0);
    final cancel = _word(context, 'Cancel', 'إلغاء');
    _reviewing = true;
    try {
      final selected = await showDialog<String>(
        context: context,
        builder: (dialog) => BilPearlMaterialAlertDialog(
          key: const Key('vision-required-details'),
          scrollable: true,
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final field in missing)
                ListTile(
                  key: ValueKey('vision-missing-${field.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.radio_button_unchecked_rounded),
                  title: Text(field.label),
                  onTap: () {
                    if (dialog.mounted &&
                        current &&
                        alive() &&
                        parent?.isActive == true) {
                      Navigator.pop(dialog, field.id);
                    }
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              key: const Key('vision-required-cancel'),
              onPressed: () {
                if (dialog.mounted) Navigator.pop(dialog);
              },
              child: Text(cancel),
            ),
          ],
        ),
      );
      if (selected == null ||
          !current ||
          !alive() ||
          parent?.isCurrent != true) {
        return;
      }
      final focus = _nodes[selected];
      final target = focus?.context;
      if (focus == null || target == null || !target.mounted) return;
      await Scrollable.ensureVisible(
        target,
        duration: MediaQuery.disableAnimationsOf(target)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        alignment: .35,
      );
      if (current &&
          alive() &&
          parent?.isCurrent == true &&
          focus.context?.mounted == true) {
        focus.requestFocus();
      }
    } finally {
      _reviewing = false;
    }
  }

  void dispose() {
    _retired = true;
    unawaited(_subscription?.cancel());
    for (final focus in _nodes.values) {
      focus.dispose();
    }
    _nodes.clear();
  }
}

extension _VisionReviewRequiredFields on _PremiumVisionReviewDialogState {
  Future<void> _attemptRequiredConfirmation() async {
    if (_confirming ||
        _closing ||
        !_requiredFields.current ||
        widget.lifetime?.isActive == false) {
      return;
    }
    if (_canContinue) {
      await _confirm();
      return;
    }
    final missing = <_VisionMissingField>[];
    if (_photoStage == null) {
      missing.add(
        _VisionMissingField(
          'stage',
          _word(
            context,
            'When was this photo taken?',
            'متى التُقطت هذه الصورة؟',
          ),
        ),
      );
    }
    final active = _selected.difference(_excluded);
    if (active.isEmpty) {
      final visible = List<int>.generate(
        _foods.length,
        (i) => i,
      ).where((i) => !_excluded.contains(i));
      final field = visible.isNotEmpty
          ? 'selection-${visible.first}'
          : _excluded.isNotEmpty
          ? 'restore-${_excluded.first}'
          : 'selection';
      missing.add(_VisionMissingField(field, _visionRequiredCopy(context, 1)));
    }
    final locale = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    for (var index = 0; index < _foods.length; index++) {
      if (!active.contains(index)) continue;
      final name = _foods[index].name;
      if (_amountMeaning[index] != true) {
        missing.add(
          _VisionMissingField(
            'eaten-$index',
            '${_visionRequiredCopy(context, 2)}: $name',
          ),
        );
      }
      final amount = double.tryParse(
        _PremiumVisionReviewDialogState._digits(_amounts[index].text),
      );
      if (amount == null ||
          !amount.isFinite ||
          amount <= 0 ||
          amount > 100000) {
        missing.add(
          _VisionMissingField(
            'amount-$index',
            '${_visionRequiredCopy(context, 3)}: $name',
          ),
        );
      }
      if (mealImageCanonicalUnit(_units[index].text, locale).trim().isEmpty) {
        missing.add(
          _VisionMissingField(
            'unit-$index',
            '${_word(context, 'Unit', 'الوحدة')}: $name',
          ),
        );
      }
    }
    await _requiredFields.review(
      context,
      missing,
      alive: () => mounted && !_closing && widget.lifetime?.isActive != false,
    );
  }
}

extension _VisionMatchRequiredFields on _PremiumTrustedMatchDialogState {
  Future<void> _attemptRequiredFood() async {
    if (_usingFood || !_requiredFields.current || !mounted) return;
    final food = _selected;
    final sourceValid =
        food != null &&
        mealVisionFoodCanBeUsed(
          food,
          evidenceOwnerKey: widget.evidenceOwnerKey,
        );
    if (food != null &&
        mealVisionFoodCanBeUsed(
          food,
          evidenceOwnerKey: widget.evidenceOwnerKey,
        ) &&
        _validPortion) {
      _usingFood = true;
      if (widget.editable) {
        Navigator.pop(
          context,
          TrustedVisionFoodSelection(
            food: food,
            amount: _currentAmount!,
            unit: _currentUnit,
          ),
        );
      } else {
        Navigator.pop(context, food);
      }
      return;
    }
    final missing = <_VisionMissingField>[];
    if (!sourceValid) {
      final eligible = widget.foods.where(
        (food) => mealVisionFoodCanBeUsed(
          food,
          evidenceOwnerKey: widget.evidenceOwnerKey,
        ),
      );
      final first = eligible.isNotEmpty
          ? eligible.first
          : widget.foods.isNotEmpty
          ? widget.foods.first
          : null;
      final target = first == null ? 'source' : 'source-${first.uuid}';
      missing.add(_VisionMissingField(target, _visionRequiredCopy(context, 4)));
    }
    if (widget.editable || widget.reviewedAmount != null) {
      final amount = _currentAmount;
      if (amount == null || !amount.isFinite || amount <= 0) {
        missing.add(
          _VisionMissingField('final-amount', _visionRequiredCopy(context, 5)),
        );
      }
      if (_currentUnit.isEmpty ||
          (sourceValid && amount != null && amount > 0 && !_validPortion)) {
        missing.add(
          _VisionMissingField(
            widget.editable ? 'final-unit' : 'source-${food?.uuid}',
            _visionRequiredCopy(context, 6),
          ),
        );
      }
    }
    await _requiredFields.review(
      context,
      missing,
      alive: () => mounted && !_usingFood,
    );
  }
}

String _visionRequiredCopy(BuildContext context, int index) =>
    (_visionRequiredRows[BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    )] ??
    _visionRequiredRows['en']!)[index];
const _visionRequiredRows = <String, List<String>>{
  "en": [
    "Complete required details",
    "Choose at least one ingredient",
    "Confirm the amount actually eaten",
    "Amount eaten",
    "Choose a trusted food source",
    "Enter a positive amount",
    "Review the amount and compatible unit",
  ],
  "ar": [
    "أكمل التفاصيل المطلوبة",
    "اختر مكوّنًا واحدًا على الأقل",
    "أكّد الكمية التي أكلتها فعلًا",
    "الكمية المأكولة",
    "اختر طعامًا من مصدر موثوق",
    "أدخل كمية موجبة",
    "راجع الكمية والوحدة المتوافقة مع الطعام",
  ],
  "fr": [
    "Complétez les informations requises",
    "Choisissez au moins un ingrédient",
    "Confirmez la quantité réellement consommée",
    "Quantité consommée",
    "Choisissez une source alimentaire fiable",
    "Saisissez une quantité positive",
    "Vérifiez la quantité et une unité compatible",
  ],
  "es": [
    "Completa los datos necesarios",
    "Elige al menos un ingrediente",
    "Confirma la cantidad que realmente comiste",
    "Cantidad consumida",
    "Elige una fuente de alimentos fiable",
    "Introduce una cantidad positiva",
    "Revisa la cantidad y una unidad compatible",
  ],
  "tr": [
    "Gerekli bilgileri tamamlayın",
    "En az bir malzeme seçin",
    "Gerçekte yediğiniz miktarı onaylayın",
    "Yenen miktar",
    "Güvenilir bir besin kaynağı seçin",
    "Pozitif bir miktar girin",
    "Miktarı ve uyumlu birimi gözden geçirin",
  ],
  "de": [
    "Erforderliche Angaben ergänzen",
    "Mindestens eine Zutat auswählen",
    "Tatsächlich gegessene Menge bestätigen",
    "Gegessene Menge",
    "Eine verlässliche Lebensmittelquelle auswählen",
    "Eine positive Menge eingeben",
    "Menge und passende Einheit prüfen",
  ],
  "it": [
    "Completa i dati necessari",
    "Scegli almeno un ingrediente",
    "Conferma la quantità effettivamente mangiata",
    "Quantità mangiata",
    "Scegli una fonte alimentare attendibile",
    "Inserisci una quantità positiva",
    "Controlla la quantità e un’unità compatibile",
  ],
  "pt-BR": [
    "Preencha os dados obrigatórios",
    "Escolha pelo menos um ingrediente",
    "Confirme a quantidade que realmente comeu",
    "Quantidade consumida",
    "Escolha uma fonte de alimentos confiável",
    "Insira uma quantidade positiva",
    "Revise a quantidade e uma unidade compatível",
  ],
  "pt-PT": [
    "Preenche os dados obrigatórios",
    "Escolhe pelo menos um ingrediente",
    "Confirma a quantidade que realmente comeste",
    "Quantidade consumida",
    "Escolhe uma fonte de alimentos fiável",
    "Introduz uma quantidade positiva",
    "Revê a quantidade e uma unidade compatível",
  ],
  "ur": [
    "مطلوبہ تفصیلات مکمل کریں",
    "کم از کم ایک جزو منتخب کریں",
    "واقعی کھائی گئی مقدار کی تصدیق کریں",
    "کھائی گئی مقدار",
    "کھانے کا معتبر ماخذ منتخب کریں",
    "صفر سے زیادہ مقدار درج کریں",
    "مقدار اور موزوں اکائی کا جائزہ لیں",
  ],
  "fa": [
    "اطلاعات ضروری را کامل کنید",
    "حداقل یک ماده را انتخاب کنید",
    "مقدار واقعاً خورده‌شده را تأیید کنید",
    "مقدار خورده‌شده",
    "یک منبع غذایی معتبر انتخاب کنید",
    "مقداری بیشتر از صفر وارد کنید",
    "مقدار و واحد سازگار را بررسی کنید",
  ],
  "hi": [
    "ज़रूरी जानकारी पूरी करें",
    "कम से कम एक सामग्री चुनें",
    "वास्तव में खाई गई मात्रा की पुष्टि करें",
    "खाई गई मात्रा",
    "भोजन का विश्वसनीय स्रोत चुनें",
    "शून्य से अधिक मात्रा दर्ज करें",
    "मात्रा और उपयुक्त इकाई की समीक्षा करें",
  ],
  "id": [
    "Lengkapi detail wajib",
    "Pilih setidaknya satu bahan",
    "Konfirmasi jumlah yang benar-benar dimakan",
    "Jumlah yang dimakan",
    "Pilih sumber makanan tepercaya",
    "Masukkan jumlah lebih dari nol",
    "Tinjau jumlah dan satuan yang sesuai",
  ],
  "ms": [
    "Lengkapkan butiran wajib",
    "Pilih sekurang-kurangnya satu bahan",
    "Sahkan jumlah yang benar-benar dimakan",
    "Jumlah yang dimakan",
    "Pilih sumber makanan yang dipercayai",
    "Masukkan jumlah melebihi sifar",
    "Semak jumlah dan unit yang serasi",
  ],
  "ja": [
    "必要な項目を入力してください",
    "食材を1つ以上選んでください",
    "実際に食べた量を確認してください",
    "食べた量",
    "信頼できる食品情報源を選んでください",
    "0より大きい量を入力してください",
    "量と対応する単位を確認してください",
  ],
  "ko": [
    "필수 정보를 입력하세요",
    "재료를 하나 이상 선택하세요",
    "실제로 먹은 양을 확인하세요",
    "먹은 양",
    "신뢰할 수 있는 식품 출처를 선택하세요",
    "0보다 큰 양을 입력하세요",
    "양과 호환되는 단위를 검토하세요",
  ],
  "zh-Hans": [
    "请填写必填信息",
    "请至少选择一种食材",
    "请确认实际食用的量",
    "已食用的量",
    "请选择可信的食物来源",
    "请输入大于零的数量",
    "请核对数量和适用单位",
  ],
  "zh-Hant": [
    "請填寫必填資訊",
    "請至少選擇一種食材",
    "請確認實際食用的量",
    "已食用的量",
    "請選擇可信的食物來源",
    "請輸入大於零的數量",
    "請核對數量和適用單位",
  ],
  "ru": [
    "Заполните обязательные поля",
    "Выберите хотя бы один ингредиент",
    "Подтвердите количество, которое вы действительно съели",
    "Съеденное количество",
    "Выберите надёжный источник данных о еде",
    "Введите количество больше нуля",
    "Проверьте количество и подходящую единицу",
  ],
  "bn": [
    "প্রয়োজনীয় তথ্য পূরণ করুন",
    "অন্তত একটি উপাদান বেছে নিন",
    "আসলে কতটা খেয়েছেন তা নিশ্চিত করুন",
    "খাওয়া পরিমাণ",
    "খাবারের নির্ভরযোগ্য উৎস বেছে নিন",
    "শূন্যের বেশি পরিমাণ লিখুন",
    "পরিমাণ এবং উপযুক্ত একক পর্যালোচনা করুন",
  ],
  "vi": [
    "Điền thông tin bắt buộc",
    "Chọn ít nhất một nguyên liệu",
    "Xác nhận lượng thực sự đã ăn",
    "Lượng đã ăn",
    "Chọn nguồn thực phẩm đáng tin cậy",
    "Nhập lượng lớn hơn không",
    "Xem lại lượng và đơn vị phù hợp",
  ],
  "th": [
    "กรอกรายละเอียดที่จำเป็น",
    "เลือกส่วนประกอบอย่างน้อยหนึ่งอย่าง",
    "ยืนยันปริมาณที่กินจริง",
    "ปริมาณที่กิน",
    "เลือกแหล่งข้อมูลอาหารที่เชื่อถือได้",
    "กรอกปริมาณที่มากกว่าศูนย์",
    "ตรวจสอบปริมาณและหน่วยที่เข้ากัน",
  ],
  "pl": [
    "Uzupełnij wymagane dane",
    "Wybierz co najmniej jeden składnik",
    "Potwierdź faktycznie zjedzoną ilość",
    "Zjedzona ilość",
    "Wybierz wiarygodne źródło danych o jedzeniu",
    "Wpisz ilość większą od zera",
    "Sprawdź ilość i zgodną jednostkę",
  ],
  "nl": [
    "Vul de vereiste gegevens in",
    "Kies ten minste één ingrediënt",
    "Bevestig de werkelijk gegeten hoeveelheid",
    "Gegeten hoeveelheid",
    "Kies een betrouwbare voedselbron",
    "Voer een hoeveelheid groter dan nul in",
    "Controleer de hoeveelheid en een passende eenheid",
  ],
  "uk": [
    "Заповніть обов’язкові поля",
    "Виберіть хоча б один інгредієнт",
    "Підтвердьте кількість, яку ви справді з’їли",
    "З’їдена кількість",
    "Виберіть надійне джерело даних про їжу",
    "Введіть кількість понад нуль",
    "Перевірте кількість і відповідну одиницю",
  ],
};
