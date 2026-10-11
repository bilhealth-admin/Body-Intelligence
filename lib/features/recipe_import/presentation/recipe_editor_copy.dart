import 'package:flutter/material.dart';
import '../../../app/localization/app_localizations.dart';

String recipeEditorText(BuildContext context, String text) {
  if (Localizations.localeOf(context).languageCode == 'ar') {
    const copy = {
      'Create recipe': 'إنشاء وصفة',
      'Edit recipe': 'تعديل الوصفة',
      'Review recipe': 'مراجعة الوصفة',
      'I reviewed the ingredients, serving size, and source links.':
          'راجعت المكونات وحجم الحصة وروابط المصادر.',
      'Nutrition not included': 'القيم الغذائية غير مكتملة',
      'No nutrition values will be inferred or invented.':
          'اربط المكونات بأطعمة ذات قيم معروفة لحساب التغذية. يمكنك حفظ الوصفة دون قيم، لكن لا تُسجّل تغذية مجهولة كأنها صفر.',
      'Nutrition with provenance': 'القيم المحسوبة لكل حصة',
      'One or more ingredients still need an exact food-record match.':
          'اضغط على المكوّن غير المرتبط واختر الطعام الصحيح من البحث.',
      'This is your confirmation, not professional nutrition verification.':
          'هذا تأكيدك للمكونات والحصص، وليس اعتمادًا غذائيًا مهنيًا.',
      'Saved recipe could not be loaded. Retry.':
          'تعذر تحميل الوصفة المحفوظة. أعد المحاولة.',
      'Account changed. Reopen the recipe.': 'تغيّر الحساب. أعد فتح الوصفة.',
      'Linked food record': 'مرتبطة بسجل الطعام',
      'Tap to choose the matching food': 'اضغط لاختيار الطعام المطابق',
      'No linked source': 'لم يُربط مصدر بعد',
      'Close': 'إغلاق',
      'Source': 'المصدر',
      'Protein': 'البروتين',
      'Carbohydrates': 'الكربوهيدرات',
      'Fat': 'الدهون',
    };
    if (copy.containsKey(text)) return copy[text]!;
  }
  return context.strings.text(text);
}
