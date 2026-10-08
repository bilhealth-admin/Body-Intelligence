import 'coach_media_food_bridge.dart';

/// New BIL-02 copy is verified in English and Arabic. Other locales deliberately
/// fall back to English until the coordinator imports reviewed translations.
final class CoachMediaBridgeCopy {
  const CoachMediaBridgeCopy({required this.arabic});
  final bool arabic;

  String get quantityTitle => arabic
      ? 'ما وزن الكمية بالغرام؟'
      : 'What is the portion weight in grams?';
  String get quantityLabel => arabic ? 'الكمية (غ)' : 'Quantity (g)';
  String get reviewTranscript => arabic
      ? 'راجع النص الصوتي قبل إرساله.'
      : 'Review your voice transcript before sending.';
  String get noFoodLogged =>
      arabic ? 'لم يُسجّل أي طعام.' : 'No food was logged.';

  String issue(CoachMediaFoodIssue issue) => switch (issue) {
    CoachMediaFoodIssue.invalidBarcode =>
      arabic
          ? 'الباركود غير صالح. تحقق من الرقم وحاول مجددًا.'
          : 'This barcode is invalid. Check the number and try again.',
    CoachMediaFoodIssue.noMatch =>
      arabic
          ? 'لا توجد مطابقة محلية موثقة. راجع اسم الطعام أو سجّله من دليل الطعام.'
          : 'No verified local match was found. Review the food name or use the food catalog.',
    CoachMediaFoodIssue.missingQuantity =>
      arabic
          ? 'أدخل وزن الكمية لمتابعة المراجعة.'
          : 'Enter the portion weight to continue the review.',
    CoachMediaFoodIssue.missingDensity =>
      arabic
          ? 'لا توجد كثافة موثقة لتحويل الملليلتر إلى غرام. أدخل الوزن بالغرام.'
          : 'No documented density converts this volume to grams. Enter the weight in grams.',
    CoachMediaFoodIssue.missingUnitWeight =>
      arabic
          ? 'لا يوجد وزن موثق لهذه الوحدة. أدخل الوزن بالغرام.'
          : 'This unit has no documented weight. Enter the weight in grams.',
    CoachMediaFoodIssue.unsupportedUnit =>
      arabic
          ? 'هذه الوحدة تحتاج إلى تحويل موثق. أدخل الوزن بالغرام.'
          : 'This unit needs a documented conversion. Enter the weight in grams.',
    CoachMediaFoodIssue.selectionRequired =>
      arabic
          ? 'اختر مطابقة الطعام التي تريد مراجعتها.'
          : 'Choose the food match you want to review.',
    CoachMediaFoodIssue.staleRequest =>
      arabic
          ? 'تغيّر الطلب أو الحساب أو الإذن. ابدأ المراجعة مجددًا.'
          : 'The request, account, or permission changed. Start the review again.',
    CoachMediaFoodIssue.unavailable =>
      arabic
          ? 'تعذرت قراءة المطابقة المحلية الآن. حاول مجددًا.'
          : 'The local match could not be read. Try again.',
    CoachMediaFoodIssue.invalidInput =>
      arabic
          ? 'تعذر التحقق من النتيجة. راجع الطعام والكمية.'
          : 'The result could not be validated. Review the food and quantity.',
  };
}
