import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../domain/food_v2/coach_food_v2.dart';
import '../../intelligence_locale_copy.dart';

/// Stable localization templates; runtime quantities are inserted afterwards.
final class CoachFoodCardCopy {
  const CoachFoodCardCopy(this.context);
  final BuildContext context;

  String tr(String en, String ar) => intelligenceText(context, en, ar);
  String get locale => Localizations.localeOf(context).toLanguageTag();
  String get unknown => tr('Unknown', 'غير معروف');
  String get estimated => tr('Estimated', 'تقديري');
  String get details => tr('Food details', 'تفاصيل الطعام');
  String get nutritionDetails => tr('Nutrition details', 'تفاصيل المغذيات');
  String get receiptActions => tr('Receipt actions', 'إجراءات الإيصال');
  String get estimatedPortion => tr('Estimated portion', 'كمية تقديرية');
  String get photoUnavailable => tr('Photo unavailable', 'الصورة غير متاحة');
  String get yes => tr('Yes, log it', 'نعم، سجّلها');
  String get adjust => tr('Adjust', 'تعديل');
  String get edit => tr('Edit', 'تعديل');
  String get undo => tr('Undo', 'تراجع');
  String get working => tr('Working…', 'جارٍ التنفيذ…');
  String get sources => tr('Sources', 'المصادر');
  String get source => tr('Source', 'المصدر');
  String get sourceConfidence => tr('Source confidence', 'الثقة في المصدر');
  String get identityConfidence =>
      tr('Identity confidence', 'الثقة في هوية الطعام');
  String get quantityConfidence => tr('Quantity confidence', 'الثقة في الكمية');
  String get quantity => tr('Quantity', 'الكمية');
  String get dailyLog => tr('View in Daily Log', 'عرض في السجل اليومي');
  String get unavailable => tr(
    'This food receipt is unavailable. Review your Daily Log.',
    'إيصال الطعام هذا غير متاح. راجع سجلك اليومي.',
  );
  String get ownerChanged => tr(
    'Your account changed. Return to Coach to continue.',
    'تغير حسابك. ارجع إلى المدرب للمتابعة.',
  );
  String get failed => tr(
    'The action could not be completed. Your review is kept.',
    'تعذر إكمال الإجراء. احتفظنا بمراجعتك.',
  );
  String get conflict => tr(
    'This meal changed. Review the current entry before editing or undoing.',
    'تغيّرت هذه الوجبة. راجع الإدخال الحالي قبل التعديل أو التراجع.',
  );
  String get closed => tr('This review is closed.', 'هذه المراجعة مغلقة.');
  String get undone => tr('Entry undone', 'تم التراجع عن الإدخال');
  String get updated => tr('Meal updated', 'تم تحديث الوجبة');
  String get removed => tr('Entry removed', 'تم حذف الإدخال');
  String get moved => tr('Meal moved', 'تم نقل الوجبة');
  String get calorieEntry => tr('Calorie entry saved', 'تم حفظ إدخال السعرات');
  String get nutritionEntry =>
      tr('Nutrition entry saved', 'تم حفظ إدخال المغذيات');
  String get unknownFood => tr('Unknown food', 'طعام غير معروف');

  String meal(String type) => switch (type) {
    'breakfast' => tr('Breakfast', 'الإفطار'),
    'lunch' => tr('Lunch', 'الغداء'),
    'dinner' => tr('Dinner', 'العشاء'),
    'snack' => tr('Snack', 'وجبة خفيفة'),
    _ => tr('Meal', 'وجبة'),
  };

  String intro(String mealType) => tr(
    'Great! I’ll log your {meal}. Here’s what I understood:',
    'حسنًا! سأسجّل {meal}. هذا ما فهمته:',
  ).replaceAll('{meal}', _mealInSentence(mealType));

  String question(String mealType) => tr(
    'Shall I log this to your {meal}?',
    'هل أسجّل هذا في {meal}؟',
  ).replaceAll('{meal}', _mealInSentence(mealType));

  String _mealInSentence(String mealType) =>
      locale.startsWith('en') ? meal(mealType).toLowerCase() : meal(mealType);

  String logged(String mealType) => tr(
    '{meal} logged',
    'تم تسجيل {meal}',
  ).replaceAll('{meal}', meal(mealType));

  String sourceKind(CoachFoodSourceKind kind) => switch (kind) {
    CoachFoodSourceKind.reference => tr('Reference', 'مرجع'),
    CoachFoodSourceKind.label => tr('Food label', 'ملصق غذائي'),
    CoachFoodSourceKind.userFixed => tr('Your fixed values', 'قيمك الثابتة'),
    CoachFoodSourceKind.calculatedRecipe => tr(
      'Calculated recipe',
      'وصفة محسوبة',
    ),
    CoachFoodSourceKind.estimated => estimated,
  };

  String nutrient(FoodNutrient nutrient) => switch (nutrient) {
    FoodNutrient.calories => tr('Calories', 'السعرات'),
    FoodNutrient.protein => tr('Protein', 'البروتين'),
    FoodNutrient.carbohydrates => tr('Carbs', 'الكربوهيدرات'),
    FoodNutrient.fat => tr('Fat', 'الدهون'),
    FoodNutrient.fiber => tr('Fiber', 'الألياف'),
    FoodNutrient.sugar => tr('Sugar', 'السكر'),
    FoodNutrient.sodium => tr('Sodium', 'الصوديوم'),
    FoodNutrient.potassium => tr('Potassium', 'البوتاسيوم'),
    FoodNutrient.calcium => tr('Calcium', 'الكالسيوم'),
    FoodNutrient.magnesium => tr('Magnesium', 'المغنيسيوم'),
    FoodNutrient.phosphorus => tr('Phosphorus', 'الفوسفور'),
    FoodNutrient.iron => tr('Iron', 'الحديد'),
    FoodNutrient.vitaminC => tr('Vitamin C', 'فيتامين ج'),
  };

  String number(double number) => NumberFormat('0.##', locale).format(number);
  String day(DateTime day) => DateFormat.yMMMd(locale).format(day);
  String confidence(CoachFoodConfidence? evidence) => evidence == null
      ? unknown
      : '${NumberFormat.percentPattern(locale).format(evidence.score)} · ${evidence.basis}';

  String amount(CoachFoodPortion portion, {bool includeGrams = false}) {
    final grams = gramAmount(portion);
    final conversion = portion.quantity.evidence.conversion;
    final String result;
    if (conversion == null) {
      result = grams;
    } else if (conversion.inputUnit == 'ml') {
      result = '${number(conversion.inputAmount)} ${tr('ml', 'مل')}';
    } else {
      result = conversion.inputAmount == 1
          ? tr('1 item', 'حبة واحدة')
          : tr(
              '{count} items',
              'عدد الحبات: {count}',
            ).replaceAll('{count}', number(conversion.inputAmount));
    }
    return includeGrams && conversion != null ? '$result ($grams)' : result;
  }

  String gramAmount(CoachFoodPortion portion) {
    final value = '${number(portion.quantity.grams)} ${tr('g', 'غ')}';
    return portion.quantity.evidence.kind == CoachFoodQuantityKind.estimated
        ? '~$value'
        : value;
  }

  String reviewLabel(CoachFoodPortion portion) {
    final conversion = portion.quantity.evidence.conversion;
    final name = _isolateName(portion.food.name);
    if (conversion?.inputUnit == 'item') {
      return '${number(conversion!.inputAmount)} $name ${_isolateMeasure('(${gramAmount(portion)})')}';
    }
    return '$name ${_isolateMeasure('(${amount(portion)})')}';
  }

  String receiptAmount(CoachFoodPortion portion) => _isolateMeasure(
    portion.quantity.evidence.conversion?.inputUnit == 'ml'
        ? amount(portion)
        : gramAmount(portion),
  );

  String _isolateName(String value) =>
      Directionality.of(context) == TextDirection.rtl
      ? '\u2068$value\u2069'
      : value;

  String _isolateMeasure(String value) =>
      Directionality.of(context) == TextDirection.rtl
      // Keep a mixed-script quantity, its unit and parentheses together.
      ? '\u2066${value.replaceAll(' ', '\u00a0')}\u2069'
      : value;
}
