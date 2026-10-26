import 'package:body_intelligence_log/shared/widgets/calendar/bil_crystal_date_picker.dart';
import 'package:body_intelligence_log/shared/widgets/bil_crystal_arrow.dart';
import 'package:flutter/material.dart';
import '../../../app/localization/app_localizations.dart';

String nutritionEntryText(BuildContext context, String en, String ar) =>
    Localizations.localeOf(context).languageCode == 'ar'
    ? ar
    : context.strings.text(en);

String canonicalNutritionNumberInput(String input) {
  const arabic = '٠١٢٣٤٥٦٧٨٩', persian = '۰۱۲۳۴۵۶۷۸۹';
  return input
      .trim()
      .replaceAll('٫', '.')
      .replaceAll(',', '.')
      .replaceAll('٬', '')
      .replaceAllMapped(RegExp(r'[٠-٩۰-۹]'), (match) {
        final digit = match[0]!;
        return '${arabic.contains(digit) ? arabic.indexOf(digit) : persian.indexOf(digit)}';
      });
}

double? parseNutritionNumber(String input) {
  final number = double.tryParse(canonicalNutritionNumberInput(input));
  return number != null && number.isFinite ? number : null;
}

const nutritionMealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
String nutritionMealType(BuildContext context, String type) => switch (type) {
  'breakfast' => nutritionEntryText(context, 'Breakfast', 'الإفطار'),
  'lunch' => nutritionEntryText(context, 'Lunch', 'الغداء'),
  'dinner' => nutritionEntryText(context, 'Dinner', 'العشاء'),
  _ => nutritionEntryText(context, 'Snack', 'وجبة خفيفة'),
};

Widget nutritionDestinationFields(
  BuildContext context, {
  required DateTime date,
  required String type,
  required bool enabled,
  required ValueChanged<DateTime> onDate,
  required ValueChanged<String> onType,
}) => Column(
  children: [
    ListTile(
      leading: const Icon(Icons.calendar_month_outlined),
      title: Text(nutritionEntryText(context, 'Diary date', 'تاريخ التسجيل')),
      subtitle: Text(MaterialLocalizations.of(context).formatFullDate(date)),
      onTap: !enabled
          ? null
          : () async {
              final picked = await showBilCrystalDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(date.year < 2000 ? date.year : 2000),
                lastDate: DateTime(date.year > 2100 ? date.year : 2100, 12, 31),
              );
              if (context.mounted && picked != null) onDate(picked);
            },
    ),
    DropdownButtonFormField<String>(
      key: ValueKey(type),
      initialValue: type,
      decoration: InputDecoration(
        labelText: nutritionEntryText(context, 'Meal', 'الوجبة'),
      ),
      items: [
        for (final value in nutritionMealTypes)
          DropdownMenuItem(
            value: value,
            child: Text(nutritionMealType(context, value)),
          ),
      ],
      onChanged: !enabled
          ? null
          : (value) {
              if (value != null) onType(value);
            },

      icon: const BilCrystalArrow(
        extent: 36,
        child: Icon(Icons.keyboard_arrow_down_rounded),
      ),
    ),
  ],
);
