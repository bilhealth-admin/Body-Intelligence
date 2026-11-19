import 'package:flutter/widgets.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy.dart';

String geminiVisionText(BuildContext context, String english) =>
    RuntimeCopy.resolve(
      english,
      BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
    ) ??
    english;

String geminiEstimateCopy(BuildContext context, int index) =>
    (_rows[BilLocalePolicy.canonicalTag(Localizations.localeOf(context))] ??
    _rows['en']!)[index];

// Notice, selection-only action, consent heading, consent disclosure.
const _rows = <String, List<String>>{
  'en': [
    'Estimated from your photo. Review the portion and nutrition before saving.',
    'Use this estimate',
    'Allow Gemini nutrition estimates?',
    'Google Gemini will estimate the pictured portion, calories and nutrients from your selected photo. These are estimates, not verified food records. Review them before saving. You can decline, use manual entry, or turn this off in Privacy settings.',
  ],
  'ar': [
    'تقدير من صورتك. راجع الحصة والقيم الغذائية قبل الحفظ.',
    'اعتمد هذا التقدير',
    'السماح بتقديرات جيميني الغذائية؟',
    'سيقدّر Google Gemini الحصة الظاهرة والسعرات والعناصر الغذائية من الصورة التي تختارها. هذه تقديرات وليست بيانات طعام موثّقة. راجعها قبل الحفظ. يمكنك الرفض أو الإدخال اليدوي أو إيقافها من إعدادات الخصوصية.',
  ],
  'fr': [
    'Estimation d’après votre photo. Vérifiez la portion et les nutriments avant d’enregistrer.',
    'Utiliser cette estimation',
    'Autoriser les estimations nutritionnelles de Gemini ?',
    'Google Gemini estimera la portion, les calories et les nutriments à partir de la photo choisie. Ce sont des estimations, pas des données alimentaires vérifiées. Vérifiez-les avant d’enregistrer. Vous pouvez refuser, saisir manuellement ou désactiver cette fonction dans Confidentialité.',
  ],
  'es': [
    'Estimación de tu foto. Revisa la porción y los nutrientes antes de guardar.',
    'Usar esta estimación',
    '¿Permitir estimaciones nutricionales de Gemini?',
    'Google Gemini estimará la porción, las calorías y los nutrientes de la foto elegida. Son estimaciones, no datos alimentarios verificados. Revísalas antes de guardar. Puedes rechazar, introducir los datos manualmente o desactivarlo en Privacidad.',
  ],
  'tr': [
    'Fotoğrafınızdan tahmin edildi. Kaydetmeden önce porsiyonu ve besinleri gözden geçirin.',
    'Bu tahmini kullan',
    'Gemini besin tahminlerine izin verilsin mi?',
    'Google Gemini, seçtiğiniz fotoğraftaki porsiyonu, kaloriyi ve besinleri tahmin eder. Bunlar doğrulanmış gıda kayıtları değil, tahminlerdir. Kaydetmeden önce inceleyin. Reddedebilir, elle giriş yapabilir veya Gizlilik ayarlarından kapatabilirsiniz.',
  ],
  'de': [
    'Aus Ihrem Foto geschätzt. Portion und Nährwerte vor dem Speichern prüfen.',
    'Diese Schätzung verwenden',
    'Gemini-Nährwertschätzungen erlauben?',
    'Google Gemini schätzt Portion, Kalorien und Nährwerte anhand Ihres ausgewählten Fotos. Dies sind Schätzungen, keine verifizierten Lebensmitteldaten. Vor dem Speichern prüfen. Sie können ablehnen, manuell eingeben oder die Funktion im Datenschutz deaktivieren.',
  ],
  'it': [
    'Stima dalla tua foto. Controlla porzione e nutrienti prima di salvare.',
    'Usa questa stima',
    'Consentire le stime nutrizionali di Gemini?',
    'Google Gemini stimerà porzione, calorie e nutrienti dalla foto scelta. Sono stime, non dati alimentari verificati. Controllale prima di salvare. Puoi rifiutare, inserire manualmente o disattivare la funzione in Privacy.',
  ],
  'pt-BR': [
    'Estimativa da sua foto. Revise a porção e os nutrientes antes de salvar.',
    'Usar esta estimativa',
    'Permitir estimativas nutricionais do Gemini?',
    'O Google Gemini estimará a porção, as calorias e os nutrientes da foto escolhida. São estimativas, não dados de alimentos verificados. Revise antes de salvar. Você pode recusar, inserir manualmente ou desativar em Privacidade.',
  ],
  'pt-PT': [
    'Estimativa da sua foto. Reveja a porção e os nutrientes antes de guardar.',
    'Usar esta estimativa',
    'Permitir estimativas nutricionais do Gemini?',
    'O Google Gemini estimará a porção, as calorias e os nutrientes da foto escolhida. São estimativas, não dados alimentares verificados. Reveja antes de guardar. Pode recusar, introduzir manualmente ou desativar em Privacidade.',
  ],
  'ur': [
    'آپ کی تصویر سے تخمینہ۔ محفوظ کرنے سے پہلے مقدار اور غذائیت دیکھ لیں۔',
    'یہ تخمینہ استعمال کریں',
    'Gemini کے غذائی تخمینوں کی اجازت دیں؟',
    'Google Gemini منتخب تصویر سے مقدار، کیلوریز اور غذائی اجزا کا تخمینہ لگائے گا۔ یہ تخمینے ہیں، تصدیق شدہ غذائی ریکارڈ نہیں۔ محفوظ کرنے سے پہلے جائزہ لیں۔ آپ انکار، دستی اندراج یا رازداری کی ترتیبات میں بند کر سکتے ہیں۔',
  ],
  'fa': [
    'برآورد از عکس شما. پیش از ذخیره، مقدار و مواد مغذی را بررسی کنید.',
    'استفاده از این برآورد',
    'اجازه برآورد تغذیه توسط Gemini؟',
    'Google Gemini مقدار، کالری و مواد مغذی را از عکس انتخابی شما برآورد می‌کند. این‌ها برآورد هستند، نه داده‌های تأییدشده غذا. پیش از ذخیره بررسی کنید. می‌توانید رد کنید، دستی وارد کنید یا در تنظیمات حریم خصوصی خاموش کنید.',
  ],
  'hi': [
    'आपकी फ़ोटो से अनुमान। सहेजने से पहले मात्रा और पोषक तत्व जाँचें।',
    'यह अनुमान इस्तेमाल करें',
    'Gemini के पोषण अनुमानों की अनुमति दें?',
    'Google Gemini चुनी हुई फ़ोटो से मात्रा, कैलोरी और पोषक तत्वों का अनुमान लगाएगा। ये अनुमान हैं, सत्यापित खाद्य रिकॉर्ड नहीं। सहेजने से पहले जाँचें। आप मना कर सकते हैं, हाथ से भर सकते हैं या गोपनीयता सेटिंग में बंद कर सकते हैं।',
  ],
  'id': [
    'Perkiraan dari foto Anda. Tinjau porsi dan nutrisi sebelum menyimpan.',
    'Gunakan perkiraan ini',
    'Izinkan perkiraan nutrisi Gemini?',
    'Google Gemini akan memperkirakan porsi, kalori, dan nutrisi dari foto pilihan Anda. Ini perkiraan, bukan data makanan terverifikasi. Tinjau sebelum menyimpan. Anda dapat menolak, memasukkan manual, atau menonaktifkan di Privasi.',
  ],
  'ms': [
    'Anggaran daripada foto anda. Semak hidangan dan nutrien sebelum menyimpan.',
    'Gunakan anggaran ini',
    'Benarkan anggaran nutrisi Gemini?',
    'Google Gemini akan menganggarkan hidangan, kalori dan nutrien daripada foto pilihan anda. Ini anggaran, bukan rekod makanan yang disahkan. Semak sebelum menyimpan. Anda boleh menolak, memasukkan secara manual atau mematikannya dalam Privasi.',
  ],
  'ja': [
    '写真からの推定です。保存前に量と栄養を確認してください。',
    'この推定を使う',
    'Geminiによる栄養推定を許可しますか？',
    'Google Geminiが選択した写真から量、カロリー、栄養素を推定します。検証済み食品データではありません。保存前に確認してください。拒否、手動入力、プライバシー設定での無効化が可能です。',
  ],
  'ko': [
    '사진으로 추정한 값입니다. 저장 전 양과 영양을 확인하세요.',
    '이 추정값 사용',
    'Gemini 영양 추정을 허용할까요?',
    'Google Gemini가 선택한 사진에서 양, 칼로리, 영양소를 추정합니다. 검증된 식품 기록이 아닌 추정값입니다. 저장 전에 확인하세요. 거절하거나 직접 입력하거나 개인정보 설정에서 끌 수 있습니다.',
  ],
  'zh-Hans': [
    '根据照片估算。保存前请检查份量和营养。',
    '使用此估算',
    '允许Gemini估算营养吗？',
    'Google Gemini将根据所选照片估算份量、热量和营养。这些是估算值，并非经核实的食品记录。保存前请检查。您可以拒绝、手动输入，或在隐私设置中关闭。',
  ],
  'zh-Hant': [
    '根據照片估算。儲存前請檢查份量和營養。',
    '使用此估算',
    '允許Gemini估算營養嗎？',
    'Google Gemini將根據所選照片估算份量、熱量和營養。這些是估算值，並非經核實的食品紀錄。儲存前請檢查。您可以拒絕、手動輸入，或在隱私設定中關閉。',
  ],
  'ru': [
    'Оценка по вашему фото. Проверьте порцию и состав перед сохранением.',
    'Использовать эту оценку',
    'Разрешить Gemini оценивать питание?',
    'Google Gemini оценит порцию, калории и питательные вещества по выбранному фото. Это оценки, а не проверенные данные о продукте. Проверьте перед сохранением. Можно отказаться, ввести вручную или отключить в настройках конфиденциальности.',
  ],
  'bn': [
    'আপনার ছবি থেকে অনুমান। সংরক্ষণের আগে পরিমাণ ও পুষ্টি দেখুন।',
    'এই অনুমান ব্যবহার করুন',
    'Gemini-এর পুষ্টির অনুমতি দেবেন?',
    'Google Gemini নির্বাচিত ছবি থেকে পরিমাণ, ক্যালোরি ও পুষ্টির অনুমান করবে। এগুলি অনুমান, যাচাইকৃত খাবারের তথ্য নয়। সংরক্ষণের আগে দেখুন। আপনি প্রত্যাখ্যান, নিজে লিখতে বা গোপনীয়তা সেটিংসে বন্ধ করতে পারেন।',
  ],
  'vi': [
    'Ước tính từ ảnh của bạn. Kiểm tra khẩu phần và dinh dưỡng trước khi lưu.',
    'Dùng ước tính này',
    'Cho phép Gemini ước tính dinh dưỡng?',
    'Google Gemini sẽ ước tính khẩu phần, calo và chất dinh dưỡng từ ảnh đã chọn. Đây là ước tính, không phải dữ liệu thực phẩm đã xác minh. Kiểm tra trước khi lưu. Bạn có thể từ chối, nhập thủ công hoặc tắt trong Quyền riêng tư.',
  ],
  'th': [
    'ค่าประมาณจากรูปของคุณ ตรวจสอบปริมาณและสารอาหารก่อนบันทึก',
    'ใช้ค่าประมาณนี้',
    'อนุญาตให้ Gemini ประมาณสารอาหารไหม?',
    'Google Gemini จะประมาณปริมาณ แคลอรี และสารอาหารจากรูปที่เลือก ข้อมูลนี้เป็นค่าประมาณ ไม่ใช่บันทึกอาหารที่ยืนยันแล้ว ตรวจสอบก่อนบันทึก คุณปฏิเสธ กรอกเอง หรือปิดได้ในการตั้งค่าความเป็นส่วนตัว',
  ],
  'pl': [
    'Oszacowanie ze zdjęcia. Sprawdź porcję i składniki przed zapisaniem.',
    'Użyj tego oszacowania',
    'Zezwolić na szacunki żywieniowe Gemini?',
    'Google Gemini oszacuje porcję, kalorie i składniki z wybranego zdjęcia. To szacunki, nie zweryfikowane dane żywności. Sprawdź przed zapisaniem. Możesz odmówić, wpisać ręcznie lub wyłączyć w Prywatności.',
  ],
  'nl': [
    'Geschat op basis van je foto. Controleer portie en voeding vóór opslaan.',
    'Deze schatting gebruiken',
    'Voedingsschattingen van Gemini toestaan?',
    'Google Gemini schat portie, calorieën en voedingsstoffen uit je gekozen foto. Dit zijn schattingen, geen geverifieerde voedselgegevens. Controleer vóór opslaan. Je kunt weigeren, handmatig invoeren of uitschakelen in Privacy.',
  ],
  'uk': [
    'Оцінка за вашим фото. Перевірте порцію та поживні речовини перед збереженням.',
    'Використати цю оцінку',
    'Дозволити Gemini оцінювати харчування?',
    'Google Gemini оцінить порцію, калорії та поживні речовини за вибраним фото. Це оцінки, а не перевірені дані про їжу. Перевірте перед збереженням. Можна відмовитися, ввести вручну або вимкнути в налаштуваннях приватності.',
  ],
};

String geminiEstimateFieldCopy(BuildContext context, int index) =>
    (_fieldRows[BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    )] ??
    _fieldRows['en']!)[index];
const _fieldRows = <String, List<String>>{
  "en": [
    "Choose at least one ingredient",
    "Enter a positive amount",
    "Review the amount and compatible unit",
  ],
  "ar": [
    "اختر مكوّنًا واحدًا على الأقل",
    "أدخل كمية موجبة",
    "راجع الكمية والوحدة المتوافقة مع الطعام",
  ],
  "fr": [
    "Choisissez au moins un ingrédient",
    "Saisissez une quantité positive",
    "Vérifiez la quantité et une unité compatible",
  ],
  "es": [
    "Elige al menos un ingrediente",
    "Introduce una cantidad positiva",
    "Revisa la cantidad y una unidad compatible",
  ],
  "tr": [
    "En az bir malzeme seçin",
    "Pozitif bir miktar girin",
    "Miktarı ve uyumlu birimi gözden geçirin",
  ],
  "de": [
    "Mindestens eine Zutat auswählen",
    "Eine positive Menge eingeben",
    "Menge und passende Einheit prüfen",
  ],
  "it": [
    "Scegli almeno un ingrediente",
    "Inserisci una quantità positiva",
    "Controlla la quantità e un’unità compatibile",
  ],
  "pt-BR": [
    "Escolha pelo menos um ingrediente",
    "Insira uma quantidade positiva",
    "Revise a quantidade e uma unidade compatível",
  ],
  "pt-PT": [
    "Escolhe pelo menos um ingrediente",
    "Introduz uma quantidade positiva",
    "Revê a quantidade e uma unidade compatível",
  ],
  "ur": [
    "کم از کم ایک جزو منتخب کریں",
    "صفر سے زیادہ مقدار درج کریں",
    "مقدار اور موزوں اکائی کا جائزہ لیں",
  ],
  "fa": [
    "حداقل یک ماده را انتخاب کنید",
    "مقداری بیشتر از صفر وارد کنید",
    "مقدار و واحد سازگار را بررسی کنید",
  ],
  "hi": [
    "कम से कम एक सामग्री चुनें",
    "शून्य से अधिक मात्रा दर्ज करें",
    "मात्रा और उपयुक्त इकाई की समीक्षा करें",
  ],
  "id": [
    "Pilih setidaknya satu bahan",
    "Masukkan jumlah lebih dari nol",
    "Tinjau jumlah dan satuan yang sesuai",
  ],
  "ms": [
    "Pilih sekurang-kurangnya satu bahan",
    "Masukkan jumlah melebihi sifar",
    "Semak jumlah dan unit yang serasi",
  ],
  "ja": ["食材を1つ以上選んでください", "0より大きい量を入力してください", "量と対応する単位を確認してください"],
  "ko": ["재료를 하나 이상 선택하세요", "0보다 큰 양을 입력하세요", "양과 호환되는 단위를 검토하세요"],
  "zh-Hans": ["请至少选择一种食材", "请输入大于零的数量", "请核对数量和适用单位"],
  "zh-Hant": ["請至少選擇一種食材", "請輸入大於零的數量", "請核對數量和適用單位"],
  "ru": [
    "Выберите хотя бы один ингредиент",
    "Введите количество больше нуля",
    "Проверьте количество и подходящую единицу",
  ],
  "bn": [
    "অন্তত একটি উপাদান বেছে নিন",
    "শূন্যের বেশি পরিমাণ লিখুন",
    "পরিমাণ এবং উপযুক্ত একক পর্যালোচনা করুন",
  ],
  "vi": [
    "Chọn ít nhất một nguyên liệu",
    "Nhập lượng lớn hơn không",
    "Xem lại lượng và đơn vị phù hợp",
  ],
  "th": [
    "เลือกส่วนประกอบอย่างน้อยหนึ่งอย่าง",
    "กรอกปริมาณที่มากกว่าศูนย์",
    "ตรวจสอบปริมาณและหน่วยที่เข้ากัน",
  ],
  "pl": [
    "Wybierz co najmniej jeden składnik",
    "Wpisz ilość większą od zera",
    "Sprawdź ilość i zgodną jednostkę",
  ],
  "nl": [
    "Kies ten minste één ingrediënt",
    "Voer een hoeveelheid groter dan nul in",
    "Controleer de hoeveelheid en een passende eenheid",
  ],
  "uk": [
    "Виберіть хоча б один інгредієнт",
    "Введіть кількість понад нуль",
    "Перевірте кількість і відповідну одиницю",
  ],
};
