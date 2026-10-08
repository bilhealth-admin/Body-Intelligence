import '../intelligence_locale_copy.dart';
import 'coach_media_food_bridge.dart';

/// Reviewed English/Arabic media copy. Unreviewed locales use the shared
/// locale catalog and its English fallback; do not branch visible text inline.
final class CoachMediaBridgeCopy {
  const CoachMediaBridgeCopy({required this.arabic});

  final bool arabic;

  String get _localeTag => switch (arabic) {
    true => 'ar',
    false => 'en',
  };

  String _text(String english, String arabicText) =>
      intelligenceTextFor(_localeTag, english, arabicText);

  String get quantityTitle => _text(
    'What is the portion weight in grams?',
    'ما وزن الكمية بالغرام؟',
  );
  String get quantityLabel => _text('Quantity (g)', 'الكمية (غ)');
  String get reviewTranscript => _text(
    'Review your voice transcript before sending.',
    'راجع النص الصوتي قبل إرساله.',
  );
  String get noFoodLogged => _text(
    'No food was logged.',
    'لم يُسجّل أي طعام.',
  );

  String issue(CoachMediaFoodIssue issue) => switch (issue) {
    CoachMediaFoodIssue.invalidBarcode => _text(
      'This barcode is invalid. Check the number and try again.',
      'الباركود غير صالح. تحقق من الرقم وحاول مجددًا.',
    ),
    CoachMediaFoodIssue.noMatch => _text(
      'No verified local match was found. Review the food name or use the food catalog.',
      'لا توجد مطابقة محلية موثقة. راجع اسم الطعام أو سجّله من دليل الطعام.',
    ),
    CoachMediaFoodIssue.missingQuantity => _text(
      'Enter the portion weight to continue the review.',
      'أدخل وزن الكمية لمتابعة المراجعة.',
    ),
    CoachMediaFoodIssue.missingDensity => _text(
      'No documented density converts this volume to grams. Enter the weight in grams.',
      'لا توجد كثافة موثقة لتحويل الملليلتر إلى غرام. أدخل الوزن بالغرام.',
    ),
    CoachMediaFoodIssue.missingUnitWeight => _text(
      'This unit has no documented weight. Enter the weight in grams.',
      'لا يوجد وزن موثق لهذه الوحدة. أدخل الوزن بالغرام.',
    ),
    CoachMediaFoodIssue.unsupportedUnit => _text(
      'This unit needs a documented conversion. Enter the weight in grams.',
      'هذه الوحدة تحتاج إلى تحويل موثق. أدخل الوزن بالغرام.',
    ),
    CoachMediaFoodIssue.selectionRequired => _text(
      'Choose the food match you want to review.',
      'اختر مطابقة الطعام التي تريد مراجعتها.',
    ),
    CoachMediaFoodIssue.staleRequest => _text(
      'The request, account, or permission changed. Start the review again.',
      'تغيّر الطلب أو الحساب أو الإذن. ابدأ المراجعة مجددًا.',
    ),
    CoachMediaFoodIssue.unavailable => _text(
      'The local match could not be read. Try again.',
      'تعذرت قراءة المطابقة المحلية الآن. حاول مجددًا.',
    ),
    CoachMediaFoodIssue.invalidInput => _text(
      'The result could not be validated. Review the food and quantity.',
      'تعذر التحقق من النتيجة. راجع الطعام والكمية.',
    ),
  };
}
