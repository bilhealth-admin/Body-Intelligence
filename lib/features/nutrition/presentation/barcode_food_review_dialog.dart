import 'package:flutter/material.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../../../data/database/app_database.dart';
import '../domain/unified_food.dart';

Set<String> get barcodeReviewTags => _BarcodeReviewCopy.supportedTags;

Future<Food?> showBarcodeFoodReviewDialog(
  BuildContext context, {
  required String barcode,
  required List<Food> candidates,
  String? ingredients,
}) async {
  if (candidates.isEmpty) return null;
  var selected = candidates.first;
  final copy = _BarcodeReviewCopy.of(Localizations.localeOf(context));
  return showDialog<Food>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(copy.title, key: const Key('barcode-food-review-title')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${copy.barcode}: $barcode'),
              const SizedBox(height: 12),
              RadioGroup<int>(
                groupValue: candidates.indexOf(selected),
                onChanged: (index) {
                  if (index != null) {
                    setDialogState(() => selected = candidates[index]);
                  }
                },
                child: Column(
                  children: [
                    for (var index = 0; index < candidates.length; index++)
                      Builder(
                        builder: (_) {
                          final food = candidates[index];
                          return RadioListTile<int>(
                            value: index,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              food.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${copy.serving}: ${_number(food.servingSize)} ${food.servingUnit}\n'
                              '${copy.source}: ${food.source} · '
                              '${food.verified ? copy.verified : copy.unverified}',
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              for (final line in _nutritionLines(selected, copy))
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(line),
                ),
              if (ingredients?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  '${copy.ingredients}: ${ingredients!.trim()}',
                  key: const Key('barcode-food-review-ingredients'),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Text(copy.notice, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(copy.cancel),
          ),
          FilledButton(
            key: const Key('barcode-food-review-confirm'),
            onPressed: () => Navigator.pop(dialogContext, selected),
            child: Text(copy.useFood),
          ),
        ],
      ),
    ),
  );
}

List<String> _nutritionLines(Food food, _BarcodeReviewCopy copy) {
  bool known(FoodNutrient nutrient) =>
      UnifiedFood.evidenceFromMask(food.nutrientEvidenceMask, nutrient);
  String amount(double value, String unit) => '${_number(value)} $unit';
  final lines = <String>[
    if (known(FoodNutrient.calories))
      '${copy.calories}: ${amount(food.calories, 'kcal')}',
    if (known(FoodNutrient.protein))
      '${copy.protein}: ${amount(food.protein, 'g')}',
    if (known(FoodNutrient.carbohydrates))
      '${copy.carbohydrates}: ${amount(food.carbs, 'g')}',
    if (known(FoodNutrient.fat)) '${copy.fat}: ${amount(food.fats, 'g')}',
    if (known(FoodNutrient.fiber)) '${copy.fiber}: ${amount(food.fiber, 'g')}',
    if (known(FoodNutrient.sugar)) '${copy.sugar}: ${amount(food.sugar, 'g')}',
    if (known(FoodNutrient.sodium))
      '${copy.sodium}: ${amount(food.sodium, 'mg')}',
  ];
  return lines.isEmpty ? <String>[copy.nutritionUnavailable] : lines;
}

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');

class _BarcodeReviewCopy {
  const _BarcodeReviewCopy({
    required this.title,
    required this.barcode,
    required this.serving,
    required this.source,
    required this.verified,
    required this.unverified,
    required this.notice,
    required this.ingredients,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.sodium,
    required this.nutritionUnavailable,
    required this.cancel,
    required this.useFood,
  });

  final String title, barcode, serving, source, verified, unverified;
  final String notice, cancel, useFood;
  final String ingredients,
      calories,
      protein,
      carbohydrates,
      fat,
      fiber,
      sugar,
      sodium,
      nutritionUnavailable;

  static _BarcodeReviewCopy of(Locale locale) {
    final tag = BilLocalePolicy.canonicalTag(locale);
    if (!BilLocalePolicy.productionTags.contains(tag)) return _all['en']!;
    return _all[tag] ??
        (throw StateError('Missing barcode food review copy for $tag.'));
  }

  static Set<String> get supportedTags => _all.keys.toSet();

  static const _all = <String, _BarcodeReviewCopy>{
    'en': _BarcodeReviewCopy(
      title: 'Review food and serving',
      barcode: 'GTIN',
      serving: 'Serving',
      source: 'Source',
      verified: 'verified',
      unverified: 'not verified',
      notice:
          'Confirm the product, source, and serving before adding it. BIL does not infer missing nutrition.',
      ingredients: 'Ingredients',
      calories: 'Calories',
      protein: 'Protein',
      carbohydrates: 'Carbohydrates',
      fat: 'Fat',
      fiber: 'Fiber',
      sugar: 'Sugar',
      sodium: 'Sodium',
      nutritionUnavailable: 'Nutrition unavailable from this source.',
      cancel: 'Cancel',
      useFood: 'Use this food',
    ),
    'ar': _BarcodeReviewCopy(
      title: 'راجع الطعام والحصة',
      barcode: 'الرمز العالمي',
      serving: 'الحصة',
      source: 'المصدر',
      verified: 'موثّق',
      unverified: 'غير موثّق',
      notice:
          'تأكد من المنتج والمصدر والحصة قبل الإضافة. لا يخمّن BIL بيانات غذائية مفقودة.',
      ingredients: 'المكونات',
      calories: 'السعرات',
      protein: 'البروتين',
      carbohydrates: 'الكربوهيدرات',
      fat: 'الدهون',
      fiber: 'الألياف',
      sugar: 'السكريات',
      sodium: 'الصوديوم',
      nutritionUnavailable: 'لا تتوفر القيم الغذائية من هذا المصدر.',
      cancel: 'إلغاء',
      useFood: 'استخدام هذا الطعام',
    ),
    'fr': _BarcodeReviewCopy(
      title: 'Vérifier l’aliment et la portion',
      barcode: 'GTIN',
      serving: 'Portion',
      source: 'Source',
      verified: 'vérifié',
      unverified: 'non vérifié',
      notice:
          'Confirmez le produit, la source et la portion avant l’ajout. BIL n’invente aucune donnée nutritionnelle.',
      ingredients: 'Ingrédients',
      calories: 'Calories',
      protein: 'Protéines',
      carbohydrates: 'Glucides',
      fat: 'Lipides',
      fiber: 'Fibres',
      sugar: 'Sucres',
      sodium: 'Sodium',
      nutritionUnavailable:
          'Valeurs nutritionnelles indisponibles pour cette source.',
      cancel: 'Annuler',
      useFood: 'Utiliser cet aliment',
    ),
    'es': _BarcodeReviewCopy(
      title: 'Revisar alimento y porción',
      barcode: 'GTIN',
      serving: 'Porción',
      source: 'Fuente',
      verified: 'verificado',
      unverified: 'sin verificar',
      notice:
          'Confirma el producto, la fuente y la porción antes de añadirlo. BIL no estima datos nutricionales faltantes.',
      ingredients: 'Ingredientes',
      calories: 'Calorías',
      protein: 'Proteínas',
      carbohydrates: 'Carbohidratos',
      fat: 'Grasas',
      fiber: 'Fibra',
      sugar: 'Azúcares',
      sodium: 'Sodio',
      nutritionUnavailable: 'Esta fuente no proporciona valores nutricionales.',
      cancel: 'Cancelar',
      useFood: 'Usar este alimento',
    ),
    'tr': _BarcodeReviewCopy(
      title: 'Yiyecek ve porsiyonu incele',
      barcode: 'GTIN',
      serving: 'Porsiyon',
      source: 'Kaynak',
      verified: 'doğrulandı',
      unverified: 'doğrulanmadı',
      notice:
          'Eklemeden önce ürünü, kaynağı ve porsiyonu doğrulayın. BIL eksik besin verilerini tahmin etmez.',
      ingredients: 'İçindekiler',
      calories: 'Kalori',
      protein: 'Protein',
      carbohydrates: 'Karbonhidrat',
      fat: 'Yağ',
      fiber: 'Lif',
      sugar: 'Şeker',
      sodium: 'Sodyum',
      nutritionUnavailable: 'Bu kaynakta besin değerleri mevcut değil.',
      cancel: 'İptal',
      useFood: 'Bu yiyeceği kullan',
    ),
    'de': _BarcodeReviewCopy(
      title: 'Lebensmittel und Portion prüfen',
      barcode: 'GTIN',
      serving: 'Portion',
      source: 'Quelle',
      verified: 'verifiziert',
      unverified: 'nicht verifiziert',
      notice:
          'Prüfe Produkt, Quelle und Portion vor dem Hinzufügen. BIL ergänzt keine fehlenden Nährwerte.',
      ingredients: 'Zutaten',
      calories: 'Kalorien',
      protein: 'Eiweiß',
      carbohydrates: 'Kohlenhydrate',
      fat: 'Fett',
      fiber: 'Ballaststoffe',
      sugar: 'Zucker',
      sodium: 'Natrium',
      nutritionUnavailable: 'Für diese Quelle sind keine Nährwerte verfügbar.',
      cancel: 'Abbrechen',
      useFood: 'Dieses Lebensmittel verwenden',
    ),
    'it': _BarcodeReviewCopy(
      title: 'Verifica alimento e porzione',
      barcode: 'GTIN',
      serving: 'Porzione',
      source: 'Fonte',
      verified: 'verificato',
      unverified: 'non verificato',
      notice:
          'Controlla il prodotto, la fonte e la porzione prima di aggiungerlo. BIL non deduce i valori nutrizionali mancanti.',
      ingredients: 'Ingredienti',
      calories: 'Calorie',
      protein: 'Proteine',
      carbohydrates: 'Carboidrati',
      fat: 'Grassi',
      fiber: 'Fibre',
      sugar: 'Zuccheri',
      sodium: 'Sodio',
      nutritionUnavailable:
          'I valori nutrizionali non sono disponibili da questa fonte.',
      cancel: 'Annulla',
      useFood: 'Usa questo alimento',
    ),
    'pt-BR': _BarcodeReviewCopy(
      title: 'Revisar alimento e porção',
      barcode: 'GTIN',
      serving: 'Porção',
      source: 'Fonte',
      verified: 'verificado',
      unverified: 'não verificado',
      notice:
          'Confirme o produto, a fonte e a porção antes de adicionar. O BIL não deduz dados nutricionais ausentes.',
      ingredients: 'Ingredientes',
      calories: 'Calorias',
      protein: 'Proteínas',
      carbohydrates: 'Carboidratos',
      fat: 'Gorduras',
      fiber: 'Fibras',
      sugar: 'Açúcares',
      sodium: 'Sódio',
      nutritionUnavailable:
          'Os valores nutricionais não estão disponíveis nesta fonte.',
      cancel: 'Cancelar',
      useFood: 'Usar este alimento',
    ),
    'pt-PT': _BarcodeReviewCopy(
      title: 'Rever alimento e porção',
      barcode: 'GTIN',
      serving: 'Porção',
      source: 'Fonte',
      verified: 'verificado',
      unverified: 'não verificado',
      notice:
          'Confirme o produto, a fonte e a porção antes de o adicionar. O BIL não deduz informação nutricional em falta.',
      ingredients: 'Ingredientes',
      calories: 'Calorias',
      protein: 'Proteína',
      carbohydrates: 'Hidratos de carbono',
      fat: 'Gordura',
      fiber: 'Fibra',
      sugar: 'Açúcares',
      sodium: 'Sódio',
      nutritionUnavailable:
          'Os valores nutricionais não estão disponíveis nesta fonte.',
      cancel: 'Cancelar',
      useFood: 'Usar este alimento',
    ),
    'ur': _BarcodeReviewCopy(
      title: 'غذا اور مقدار کا جائزہ لیں',
      barcode: 'GTIN',
      serving: 'مقدار',
      source: 'ماخذ',
      verified: 'تصدیق شدہ',
      unverified: 'غیر تصدیق شدہ',
      notice:
          'شامل کرنے سے پہلے پروڈکٹ، ماخذ اور مقدار کی تصدیق کریں۔ BIL گم شدہ غذائی معلومات کا اندازہ نہیں لگاتا۔',
      ingredients: 'اجزاء',
      calories: 'کیلوریز',
      protein: 'پروٹین',
      carbohydrates: 'کاربوہائیڈریٹس',
      fat: 'چکنائی',
      fiber: 'فائبر',
      sugar: 'شکر',
      sodium: 'سوڈیم',
      nutritionUnavailable: 'اس ماخذ سے غذائی اقدار دستیاب نہیں ہیں۔',
      cancel: 'منسوخ',
      useFood: 'یہ غذا استعمال کریں',
    ),
    'fa': _BarcodeReviewCopy(
      title: 'بررسی غذا و مقدار مصرف',
      barcode: 'GTIN',
      serving: 'مقدار مصرف',
      source: 'منبع',
      verified: 'تأییدشده',
      unverified: 'تأییدنشده',
      notice:
          'پیش از افزودن، محصول، منبع و مقدار مصرف را تأیید کنید. BIL اطلاعات تغذیه‌ای ناقص را حدس نمی‌زند.',
      ingredients: 'مواد تشکیل‌دهنده',
      calories: 'کالری',
      protein: 'پروتئین',
      carbohydrates: 'کربوهیدرات',
      fat: 'چربی',
      fiber: 'فیبر',
      sugar: 'قند',
      sodium: 'سدیم',
      nutritionUnavailable: 'ارزش‌های تغذیه‌ای از این منبع در دسترس نیست.',
      cancel: 'لغو',
      useFood: 'استفاده از این غذا',
    ),
    'hi': _BarcodeReviewCopy(
      title: 'भोजन और परोसने की मात्रा जाँचें',
      barcode: 'GTIN',
      serving: 'परोसने की मात्रा',
      source: 'स्रोत',
      verified: 'सत्यापित',
      unverified: 'असत्यापित',
      notice:
          'जोड़ने से पहले उत्पाद, स्रोत और परोसने की मात्रा की पुष्टि करें। BIL अनुपलब्ध पोषण जानकारी का अनुमान नहीं लगाता।',
      ingredients: 'सामग्री',
      calories: 'कैलोरी',
      protein: 'प्रोटीन',
      carbohydrates: 'कार्बोहाइड्रेट',
      fat: 'वसा',
      fiber: 'फाइबर',
      sugar: 'शर्करा',
      sodium: 'सोडियम',
      nutritionUnavailable: 'इस स्रोत से पोषण मान उपलब्ध नहीं हैं।',
      cancel: 'रद्द करें',
      useFood: 'इस भोजन का उपयोग करें',
    ),
    'id': _BarcodeReviewCopy(
      title: 'Tinjau makanan dan porsi',
      barcode: 'GTIN',
      serving: 'Porsi',
      source: 'Sumber',
      verified: 'terverifikasi',
      unverified: 'belum terverifikasi',
      notice:
          'Konfirmasikan produk, sumber, dan porsi sebelum menambahkannya. BIL tidak memperkirakan data gizi yang hilang.',
      ingredients: 'Bahan',
      calories: 'Kalori',
      protein: 'Protein',
      carbohydrates: 'Karbohidrat',
      fat: 'Lemak',
      fiber: 'Serat',
      sugar: 'Gula',
      sodium: 'Natrium',
      nutritionUnavailable: 'Nilai gizi tidak tersedia dari sumber ini.',
      cancel: 'Batal',
      useFood: 'Gunakan makanan ini',
    ),
    'ms': _BarcodeReviewCopy(
      title: 'Semak makanan dan saiz hidangan',
      barcode: 'GTIN',
      serving: 'Saiz hidangan',
      source: 'Sumber',
      verified: 'disahkan',
      unverified: 'belum disahkan',
      notice:
          'Sahkan produk, sumber dan saiz hidangan sebelum menambahkannya. BIL tidak menganggar maklumat pemakanan yang tiada.',
      ingredients: 'Ramuan',
      calories: 'Kalori',
      protein: 'Protein',
      carbohydrates: 'Karbohidrat',
      fat: 'Lemak',
      fiber: 'Serat',
      sugar: 'Gula',
      sodium: 'Natrium',
      nutritionUnavailable:
          'Nilai pemakanan tidak tersedia daripada sumber ini.',
      cancel: 'Batal',
      useFood: 'Gunakan makanan ini',
    ),
    'ja': _BarcodeReviewCopy(
      title: '食品と1食分を確認',
      barcode: 'GTIN',
      serving: '1食分',
      source: '情報源',
      verified: '確認済み',
      unverified: '未確認',
      notice: '追加する前に、商品、情報源、1食分を確認してください。BIL は不足している栄養情報を推測しません。',
      ingredients: '原材料',
      calories: 'カロリー',
      protein: 'たんぱく質',
      carbohydrates: '炭水化物',
      fat: '脂質',
      fiber: '食物繊維',
      sugar: '糖類',
      sodium: 'ナトリウム',
      nutritionUnavailable: 'この情報源では栄養成分を確認できません。',
      cancel: 'キャンセル',
      useFood: 'この食品を使用',
    ),
    'ko': _BarcodeReviewCopy(
      title: '식품 및 1회 제공량 검토',
      barcode: 'GTIN',
      serving: '1회 제공량',
      source: '출처',
      verified: '확인됨',
      unverified: '확인되지 않음',
      notice: '추가하기 전에 제품, 출처 및 1회 제공량을 확인하세요. BIL은 누락된 영양 정보를 추정하지 않습니다.',
      ingredients: '원재료',
      calories: '칼로리',
      protein: '단백질',
      carbohydrates: '탄수화물',
      fat: '지방',
      fiber: '식이섬유',
      sugar: '당류',
      sodium: '나트륨',
      nutritionUnavailable: '이 출처에서는 영양 정보를 제공하지 않습니다.',
      cancel: '취소',
      useFood: '이 식품 사용',
    ),
    'zh-Hans': _BarcodeReviewCopy(
      title: '检查食品和份量',
      barcode: 'GTIN',
      serving: '份量',
      source: '来源',
      verified: '已验证',
      unverified: '未验证',
      notice: '添加前请确认产品、来源和份量。BIL 不会推断缺失的营养信息。',
      ingredients: '配料',
      calories: '热量',
      protein: '蛋白质',
      carbohydrates: '碳水化合物',
      fat: '脂肪',
      fiber: '膳食纤维',
      sugar: '糖',
      sodium: '钠',
      nutritionUnavailable: '此来源未提供营养值。',
      cancel: '取消',
      useFood: '使用此食品',
    ),
    'zh-Hant': _BarcodeReviewCopy(
      title: '檢查食品和份量',
      barcode: 'GTIN',
      serving: '份量',
      source: '來源',
      verified: '已驗證',
      unverified: '未驗證',
      notice: '新增前請確認產品、來源和份量。BIL 不會推測缺少的營養資訊。',
      ingredients: '成分',
      calories: '熱量',
      protein: '蛋白質',
      carbohydrates: '碳水化合物',
      fat: '脂肪',
      fiber: '膳食纖維',
      sugar: '糖',
      sodium: '鈉',
      nutritionUnavailable: '此來源未提供營養值。',
      cancel: '取消',
      useFood: '使用此食品',
    ),
    'ru': _BarcodeReviewCopy(
      title: 'Проверка продукта и порции',
      barcode: 'GTIN',
      serving: 'Порция',
      source: 'Источник',
      verified: 'проверено',
      unverified: 'не проверено',
      notice:
          'Проверьте продукт, источник и порцию перед добавлением. BIL не додумывает отсутствующие данные о питании.',
      ingredients: 'Ингредиенты',
      calories: 'Калории',
      protein: 'Белки',
      carbohydrates: 'Углеводы',
      fat: 'Жиры',
      fiber: 'Клетчатка',
      sugar: 'Сахар',
      sodium: 'Натрий',
      nutritionUnavailable: 'В этом источнике нет данных о пищевой ценности.',
      cancel: 'Отмена',
      useFood: 'Использовать продукт',
    ),
    'bn': _BarcodeReviewCopy(
      title: 'খাবার ও পরিবেশনের পরিমাণ পর্যালোচনা করুন',
      barcode: 'GTIN',
      serving: 'পরিবেশনের পরিমাণ',
      source: 'উৎস',
      verified: 'যাচাইকৃত',
      unverified: 'যাচাই করা হয়নি',
      notice:
          'যোগ করার আগে পণ্য, উৎস ও পরিবেশনের পরিমাণ নিশ্চিত করুন। BIL অনুপস্থিত পুষ্টির তথ্য অনুমান করে না।',
      ingredients: 'উপাদান',
      calories: 'ক্যালরি',
      protein: 'প্রোটিন',
      carbohydrates: 'কার্বোহাইড্রেট',
      fat: 'চর্বি',
      fiber: 'আঁশ',
      sugar: 'চিনি',
      sodium: 'সোডিয়াম',
      nutritionUnavailable: 'এই উৎস থেকে পুষ্টির মান পাওয়া যায়নি।',
      cancel: 'বাতিল',
      useFood: 'এই খাবার ব্যবহার করুন',
    ),
    'vi': _BarcodeReviewCopy(
      title: 'Xem lại thực phẩm và khẩu phần',
      barcode: 'GTIN',
      serving: 'Khẩu phần',
      source: 'Nguồn',
      verified: 'đã xác minh',
      unverified: 'chưa xác minh',
      notice:
          'Xác nhận sản phẩm, nguồn và khẩu phần trước khi thêm. BIL không suy đoán thông tin dinh dưỡng còn thiếu.',
      ingredients: 'Thành phần',
      calories: 'Calo',
      protein: 'Chất đạm',
      carbohydrates: 'Carbohydrate',
      fat: 'Chất béo',
      fiber: 'Chất xơ',
      sugar: 'Đường',
      sodium: 'Natri',
      nutritionUnavailable: 'Nguồn này không cung cấp giá trị dinh dưỡng.',
      cancel: 'Hủy',
      useFood: 'Dùng thực phẩm này',
    ),
    'th': _BarcodeReviewCopy(
      title: 'ตรวจสอบอาหารและปริมาณต่อหน่วยบริโภค',
      barcode: 'GTIN',
      serving: 'ปริมาณต่อหน่วยบริโภค',
      source: 'แหล่งข้อมูล',
      verified: 'ตรวจสอบแล้ว',
      unverified: 'ยังไม่ตรวจสอบ',
      notice:
          'ยืนยันผลิตภัณฑ์ แหล่งข้อมูล และปริมาณต่อหน่วยบริโภคก่อนเพิ่ม BIL จะไม่คาดเดาข้อมูลโภชนาการที่ขาดหายไป',
      ingredients: 'ส่วนประกอบ',
      calories: 'แคลอรี',
      protein: 'โปรตีน',
      carbohydrates: 'คาร์โบไฮเดรต',
      fat: 'ไขมัน',
      fiber: 'ใยอาหาร',
      sugar: 'น้ำตาล',
      sodium: 'โซเดียม',
      nutritionUnavailable: 'ไม่มีข้อมูลโภชนาการจากแหล่งข้อมูลนี้',
      cancel: 'ยกเลิก',
      useFood: 'ใช้อาหารนี้',
    ),
    'pl': _BarcodeReviewCopy(
      title: 'Sprawdź produkt i porcję',
      barcode: 'GTIN',
      serving: 'Porcja',
      source: 'Źródło',
      verified: 'zweryfikowane',
      unverified: 'niezweryfikowane',
      notice:
          'Przed dodaniem potwierdź produkt, źródło i porcję. BIL nie uzupełnia brakujących danych żywieniowych.',
      ingredients: 'Składniki',
      calories: 'Kalorie',
      protein: 'Białko',
      carbohydrates: 'Węglowodany',
      fat: 'Tłuszcz',
      fiber: 'Błonnik',
      sugar: 'Cukry',
      sodium: 'Sód',
      nutritionUnavailable:
          'W tym źródle nie ma dostępnych wartości odżywczych.',
      cancel: 'Anuluj',
      useFood: 'Użyj tego produktu',
    ),
    'nl': _BarcodeReviewCopy(
      title: 'Voedingsmiddel en portie controleren',
      barcode: 'GTIN',
      serving: 'Portie',
      source: 'Bron',
      verified: 'geverifieerd',
      unverified: 'niet geverifieerd',
      notice:
          'Controleer het product, de bron en de portie voordat je het toevoegt. BIL vult ontbrekende voedingswaarden niet in.',
      ingredients: 'Ingrediënten',
      calories: 'Calorieën',
      protein: 'Eiwit',
      carbohydrates: 'Koolhydraten',
      fat: 'Vet',
      fiber: 'Vezels',
      sugar: 'Suiker',
      sodium: 'Natrium',
      nutritionUnavailable:
          'Voedingswaarden zijn niet beschikbaar via deze bron.',
      cancel: 'Annuleren',
      useFood: 'Dit voedingsmiddel gebruiken',
    ),
    'uk': _BarcodeReviewCopy(
      title: 'Перевірка продукту та порції',
      barcode: 'GTIN',
      serving: 'Порція',
      source: 'Джерело',
      verified: 'перевірено',
      unverified: 'не перевірено',
      notice:
          'Перевірте продукт, джерело та порцію перед додаванням. BIL не вигадує відсутні дані про харчову цінність.',
      ingredients: 'Інгредієнти',
      calories: 'Калорії',
      protein: 'Білки',
      carbohydrates: 'Вуглеводи',
      fat: 'Жири',
      fiber: 'Клітковина',
      sugar: 'Цукор',
      sodium: 'Натрій',
      nutritionUnavailable: 'У цьому джерелі немає даних про харчову цінність.',
      cancel: 'Скасувати',
      useFood: 'Використати цей продукт',
    ),
  };
}
