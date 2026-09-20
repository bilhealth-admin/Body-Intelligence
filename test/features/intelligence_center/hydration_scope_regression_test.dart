import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_center_engine.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hydration question returns safe guidance without action', () async {
    final reply = await const IntelligenceCenterEngine().answer(
      question: 'Give a safe hydration tip',
      arabic: false,
    );
    expect(reply.message.text, contains('Sip water regularly'));
    expect(reply.actions, isEmpty);
  });

  test('Arabic sleep question is not misclassified as a water command', () {
    const parser = LocalCoachCommandParser();
    final actions = parser.parse(
      'أعطني نصيحة آمنة لتحسين نومي دون اختلاق أي بيانات عني',
      locale: 'ar',
    );
    expect(actions, isEmpty);
  });

  test('short unit markers only match whole tokens', () {
    const parser = LocalCoachCommandParser();
    expect(parser.parse('اعطيني نصيحه اعمل اللي بتحس', locale: 'ar'), isEmpty);
    expect(
      parser.parse('سجل 250 مل ماء', locale: 'ar').single.payload['amountMl'],
      250,
    );
    expect(
      parser.parse('log 250 ml water', locale: 'en').single.payload['amountMl'],
      250,
    );
  });

  test('water guidance stays ordinary coaching text', () {
    const parser = LocalCoachCommandParser();
    for (final question in [
      'هل شرب الماء قبل النوم مفيد؟',
      'give me advice about water and sleep',
      'اعطني نصيحة عن المياه، من فضلك',
      'water / hydration advice',
    ]) {
      expect(parser.parse(question, locale: 'ar'), isEmpty, reason: question);
    }
  });

  test('Arabic digits diacritics punctuation and mixed units parse safely', () {
    const parser = LocalCoachCommandParser();
    final cases = <(String, int)>[
      ('سَجِّل ٢٥٠ مِل ماء.', 250),
      ('أضف ۳۰۰ ml من الماء', 300),
      ('water: 500 ML', 500),
      ('شربت ١٥٠مل ماء', 150),
    ];
    for (final (input, expected) in cases) {
      final actions = parser.parse(input, locale: 'ar');
      expect(actions, hasLength(1), reason: input);
      expect(actions.single.payload['amountMl'], expected, reason: input);
    }
  });

  test('short markers inside Arabic and Latin words never trigger water', () {
    const parser = LocalCoachCommandParser();
    for (final input in [
      'اعمل ما تراه مناسبا',
      'هذا مكمل غذائي فقط',
      'small improvements help',
      'formula discussion',
      'suplemento general',
    ]) {
      expect(parser.parse(input, locale: 'ar'), isEmpty, reason: input);
    }
  });

  test('local fallback follows Arabic question under Chinese UI', () async {
    final reply = await const IntelligenceCenterEngine().answer(
      question: 'أعطني نصيحة آمنة لتحسين نومي دون اختلاق أي بيانات عني',
      arabic: false,
      localeCode: 'zh-Hans',
    );
    expect(reply.message.text, contains(RegExp(r'[\u0600-\u06ff]')));
    expect(reply.actions, isEmpty);
  });
}
