import 'package:flutter/widgets.dart';

import '../../../app/localization/app_localizations.dart';

part 'wellness_copy_catalog_a.dart';
part 'wellness_copy_catalog_b.dart';
part 'wellness_engine_locale_copy.dart';

abstract final class WellnessCopyCatalog {
  static const supportedLanguageCodes = {'ar', 'en', 'fr', 'es', 'tr'};
  static const secondaryLanguageCodes = {'fr', 'es', 'tr'};

  static bool get catalogsBalanced => _wellnessSecondary.values.every(
    (translations) =>
        translations.keys.toSet().containsAll(secondaryLanguageCodes) &&
        secondaryLanguageCodes.containsAll(translations.keys),
  );
}

String wellnessCopy(BuildContext context, String english, String arabic) {
  final code = Localizations.localeOf(context).languageCode.toLowerCase();
  if (code == 'ar') return arabic;
  if (code == 'en') return english;

  final engineCopy =
      _wellnessEngineCorePatch[english]?[code] ??
      _wellnessEngineExtended[english]?[code];
  if (engineCopy != null) return engineCopy;

  final recipeCount = RegExp(r'^(\d+) of (\d+) recipes$').firstMatch(english);
  if (recipeCount != null) {
    return context.strings
        .text('{visible} of {total} recipes')
        .replaceFirst('{visible}', recipeCount.group(1)!)
        .replaceFirst('{total}', recipeCount.group(2)!);
  }
  final minutesOnly = RegExp(r'^(\d+) min$').firstMatch(english);
  if (minutesOnly != null) {
    return context.strings
        .text('{count} min')
        .replaceFirst('{count}', minutesOnly.group(1)!);
  }
  final originalLanguage = RegExp(
    r'^Original · ([A-Z-]+)$',
  ).firstMatch(english);
  if (originalLanguage != null) {
    return context.strings
        .text('Original · {language}')
        .replaceFirst('{language}', originalLanguage.group(1)!);
  }

  String dynamicCopy(String prefix, String suffix) => switch (code) {
    'fr' => '$prefix$suffix',
    'es' => '$prefix$suffix',
    'tr' => '$prefix$suffix',
    _ => english,
  };

  if (english.startsWith('Recorded today: ')) {
    final value = english.substring('Recorded today: '.length);
    if (!WellnessCopyCatalog.supportedLanguageCodes.contains(code)) {
      return context.strings
          .text('Recorded today: {value}')
          .replaceFirst('{value}', value);
    }
    return dynamicCopy(switch (code) {
      'fr' => "Enregistré aujourd’hui : ",
      'es' => 'Registrado hoy: ',
      'tr' => 'Bugün kaydedilen: ',
      _ => '',
    }, value);
  }
  if (english.startsWith('Duration: ')) {
    final value = english.substring('Duration: '.length);
    if (!WellnessCopyCatalog.supportedLanguageCodes.contains(code)) {
      return context.strings
          .text('Duration: {value}')
          .replaceFirst('{value}', value);
    }
    return dynamicCopy(switch (code) {
      'fr' => 'Durée : ',
      'es' => 'Duración: ',
      'tr' => 'Süre: ',
      _ => '',
    }, value);
  }
  if (english.startsWith('of ') && english.endsWith(' hours')) {
    final value = english.substring(3, english.length - 6);
    return switch (code) {
      'fr' => 'sur $value heures',
      'es' => 'de $value horas',
      'tr' => '$value saatin',
      _ =>
        context.strings.text('of {value} hours').replaceFirst('{value}', value),
    };
  }
  if (english.contains(' recorded nights · ') &&
      english.endsWith(' h average')) {
    final parts = english.split(' recorded nights · ');
    final average = parts[1].replaceFirst(' h average', '');
    return switch (code) {
      'fr' => '${parts[0]} nuits enregistrées · moyenne $average h',
      'es' => '${parts[0]} noches registradas · media de $average h',
      'tr' => '${parts[0]} kayıtlı gece · ortalama $average sa',
      _ =>
        context.strings
            .text('{count} recorded nights · {average} h average')
            .replaceFirst('{count}', parts[0])
            .replaceFirst('{average}', average),
    };
  }
  final recipeSummary = RegExp(
    r'^(\d+) min • (\d+) ingredients$',
  ).firstMatch(english);
  if (recipeSummary != null) {
    final minutes = recipeSummary.group(1);
    final count = recipeSummary.group(2);
    return switch (code) {
      'fr' => '$minutes min • $count ingrédients',
      'es' => '$minutes min • $count ingredientes',
      'tr' => '$minutes dk • $count malzeme',
      _ =>
        context.strings
            .text('{minutes} min • {count} ingredients')
            .replaceFirst('{minutes}', minutes!)
            .replaceFirst('{count}', count!),
    };
  }
  final guidance = RegExp(
    r'^(\d+) minutes • guidance quantities$',
  ).firstMatch(english);
  if (guidance != null) {
    final minutes = guidance.group(1);
    return switch (code) {
      'fr' => '$minutes minutes • quantités indicatives',
      'es' => '$minutes minutos • cantidades orientativas',
      'tr' => '$minutes dakika • rehber miktarlar',
      _ =>
        context.strings
            .text('{minutes} minutes • guidance quantities')
            .replaceFirst('{minutes}', minutes!),
    };
  }

  return _wellnessSecondary[english]?[code] ?? context.strings.text(english);
}

const _wellnessSecondary = <String, Map<String, String>>{
  ..._wellnessSecondaryA,
  ..._wellnessSecondaryB,
};
