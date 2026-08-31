import 'dart:io';
import 'package:body_intelligence_log/features/nutrition/services/food_search_assistance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const assistance = FoodSearchAssistance();

  test('offline bilingual search covers cuts and spelling', () {
    expect(assistance.expand('دجاج'), contains('chicken'));
    expect(assistance.expand('فخذ دجاج'), contains('thigh chicken'));
    expect(assistance.expand('ورك'), contains(anyOf('thigh', 'leg')));
    expect(assistance.expand('صدر'), contains('breast'));
    expect(assistance.expand('شيكن'), contains('chicken'));
    expect(assistance.correctionFor('دجاد'), isNotNull);
    expect(assistance.correctionFor('chek'), 'chicken');
    expect(assistance.correctionFor('chiken'), 'chicken');
  });

  test('English food labels produce Arabic labels', () {
    expect(
      assistance.arabicNameFor('Chicken breast roasted skinless'),
      contains('دجاج'),
    );
    expect(assistance.arabicNameFor('Chicken thigh raw'), contains('فخذ'));
    expect(assistance.arabicNameFor('Apples Fuji raw'), contains('تفاح'));
  });

  test('Windows camera and the in-app food guide route are enabled', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final scanner = File(
      'lib/features/nutrition/presentation/food_barcode_scanner_page.dart',
    ).readAsStringSync();
    final foodPage = File(
      'lib/features/nutrition/food_page.dart',
    ).readAsStringSync();
    expect(pubspec, contains('simple_barcode_scanner: ^0.6.0'));
    expect(scanner, contains('SimpleBarcodeScanner.scanBarcode'));
    expect(scanner, contains('TargetPlatform.windows'));
    expect(foodPage, contains("context.push('/food-libraries')"));
    expect(
      foodPage,
      isNot(contains('https://fdc.nal.usda.gov/download-datasets/')),
      reason: 'A failed search must stay inside the installable food guide.',
    );
  });
}
