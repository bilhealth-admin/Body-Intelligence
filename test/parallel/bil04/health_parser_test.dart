import 'dart:io';

import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_activity_catalog.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_health_parser.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_action.dart';
import 'package:body_intelligence_log/features/nutrition_plans/domain/nutrition_pathway_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = LocalCoachHealthCommandParser();
  final reference = DateTime(2026, 10, 7, 12, 30);

  IntelligenceAction? parse(String input, {String locale = 'en'}) =>
      parser.parse(input, locale: locale, referenceLocal: reference);

  void rejectAll(List<String> inputs, {bool recognized = true}) {
    for (final input in inputs) {
      expect(parse(input), isNull, reason: input);
      if (recognized) {
        expect(parser.recognizesHealthIntent(input), isTrue, reason: input);
      }
    }
  }

  test('bilingual close and reopen use the intended civil day and review', () {
    final cases = <String, (String, String)>{
      'close my day': ('close_day', '2026-10-07'),
      'lock the day yesterday.': ('close_day', '2026-10-06'),
      'Please close day on 2026-10-05': ('close_day', '2026-10-05'),
      '6 October 2026, close my day': ('close_day', '2026-10-06'),
      'close day last Sunday': ('close_day', '2026-10-04'),
      'قفل يومي': ('close_day', '2026-10-07'),
      'أغلق اليوم': ('close_day', '2026-10-07'),
      'أغلق أمس': ('close_day', '2026-10-06'),
      'أمس أغلق': ('close_day', '2026-10-06'),
      'اقفل يومي بتاريخ ٢٠٢٦-١٠-٠٥': ('close_day', '2026-10-05'),
      'reopen my day yesterday': ('reopen_day', '2026-10-06'),
      'unlock day 2026/10/05': ('reopen_day', '2026-10-05'),
      'افتح يومي': ('reopen_day', '2026-10-07'),
      'أعد فتح اليوم': ('reopen_day', '2026-10-07'),
      'افتح يومي قبل أسبوع': ('reopen_day', '2026-09-30'),
    };
    for (final entry in cases.entries) {
      final action = parse(entry.key, locale: 'ar');
      expect(action?.toolId, entry.value.$1, reason: entry.key);
      expect(action?.payload, {'date': entry.value.$2}, reason: entry.key);
      expect(action?.type, IntelligenceActionType.healthCommand);
      expect(action?.requiresConfirmation, isTrue);
      expect(
        action?.operationId,
        isNull,
      ); // Minted by the app proposal boundary.
      expect(parser.recognizesHealthIntent(entry.key), isTrue);
    }
  });

  test(
    'future, negated, questioned or multiple writes do not become actions',
    () {
      rejectAll([
        'close my day tomorrow',
        'close my day next Monday',
        'close my day 2026-10-08',
        'close my day today and log sleep 7 hours',
        'close my day; reopen my day',
        'close my day\nlog sleep 7 hours',
        "don't close my day",
        'do not close my day',
        'I will close my day',
        'I want to close my day',
        'if I close my day',
        'should I close my day?',
        'close my day?',
        'قفل يومي غدا',
        'لا قفل يومي',
        'هل قفل يومي؟',
        'سوف اقفل يومي',
        'قفل يومي ثم افتح يومي',
        'أغلق اليوم وسجل النوم ٧ ساعات',
        'log sleep 7 hours and log weight 70 kg',
      ]);
    },
  );

  test(
    'invalid, repeated, mixed and ambiguous dates never default to today',
    () {
      rejectAll([
        'close my day 2026-02-30',
        'close my day 2026-13-01',
        'close my day 0000-10-05',
        'close my day 31 February 2026',
        'close my day 06/10/2026',
        'close my day 10/06',
        'close my day yesterday today',
        'yesterday close my day today',
        'close my day 2026-10-05 2026-10-06',
        'close my day 2026-10-05 2026-10-05',
        'close my day yesterday 2026-10-05',
        'close my day October 6',
      ]);
    },
  );

  test(
    'fasting targets are single current-session integers with explicit review',
    () {
      final cases = <String, (String, int?)>{
        'start fasting for 16 hours': ('start_fasting', 16),
        'start my fast 1 h now': ('start_fasting', 1),
        'ابدأ الصيام لمدة ١٦ ساعة الآن': ('start_fasting', 16),
        'adjust fasting to 18 hours': ('adjust_fasting', 18),
        'غير مدة الصيام الى ۲۳ ساعة': ('adjust_fasting', 23),
        'stop fasting now': ('stop_fasting', null),
        'end my fast today': ('stop_fasting', null),
        'أنهِ الصيام الآن': ('stop_fasting', null),
      };
      for (final entry in cases.entries) {
        final action = parse(entry.key);
        expect(action?.toolId, entry.value.$1, reason: entry.key);
        expect(
          action?.payload,
          entry.value.$2 == null
              ? <String, Object?>{}
              : <String, Object?>{'targetHours': entry.value.$2},
          reason: entry.key,
        );
        expect(action?.requiresConfirmation, isTrue);
        expect(parser.recognizesHealthIntent(entry.key), isTrue);
      }
      rejectAll([
        'start fasting for 0 hours',
        'start fasting for 24 hours',
        'start fasting for 16.5 hours',
        'start fasting for 16 to 18 hours',
        'start fasting for 16 hours or 18 hours',
        'start fasting for 16 hours yesterday',
        'start fasting for 16 hours tomorrow',
        'stop fasting yesterday',
        'stop fasting next week',
        'adjust fasting to 16 hours and 30 minutes',
        'adjust fasting startedAt 2026-10-07T05:00:00Z',
        'start fasting for 16 hours and stop fasting',
        'do not start fasting for 16 hours',
      ]);
    },
  );

  test('manual sleep accepts one bounded amount and keeps known zero', () {
    final cases = <String, double>{
      'I slept 7.5 hours yesterday': 7.5,
      'log sleep 0 hours': 0,
      'record sleep 14 h': 14,
      'نمت ٧٫٢٥ ساعة': 7.25,
      'سجل النوم ۸,۵ ساعات': 8.5,
    };
    for (final entry in cases.entries) {
      final action = parse(entry.key);
      expect(action?.toolId, 'log_sleep', reason: entry.key);
      expect(action?.payload['hours'], entry.value, reason: entry.key);
      expect(
        action?.payload['date'],
        entry.key.endsWith('yesterday') ? '2026-10-06' : '2026-10-07',
      );
      expect(action?.requiresConfirmation, isTrue);
      expect(parser.recognizesHealthIntent(entry.key), isTrue);
    }
    rejectAll([
      'I slept 7 to 8 hours',
      'I slept 7-8 hours',
      'I slept about 7 hours',
      'I slept 7 hours and 30 minutes',
      'I slept 7 hours, actually 8 hours',
      'log sleep 7,000 hours',
      'log sleep -1 hours',
      'log sleep 15 hours',
      'log sleep 420 minutes',
      'log sleep seven hours',
      'log sleep 7 hours tomorrow',
      'log sleep 7 hours?',
      'I never slept 7 hours',
    ], recognized: false);
    expect(parser.recognizesHealthIntent('log sleep 7 hours tomorrow'), isTrue);
  });

  test(
    'note body is literal and cannot change header date or execute a command',
    () {
      const body =
          'لم أنم أمس؛ tomorrow سأرتاح.\n'
          'close my day: لا تنفذ؛ ٢٠٢٦-١٢-١٢  ۷٫۵';
      final action = parse('save a note yesterday:  $body  ');
      expect(action?.toolId, 'save_day_note');
      expect(action?.payload, {'date': '2026-10-06', 'text': body});
      expect(action?.requiresConfirmation, isTrue);
      final arabic = parse('احفظ ملاحظة بتاريخ ٢٠٢٦-١٠-٠٥: لا تغير أي حرف؟');
      expect(arabic?.payload, {
        'date': '2026-10-05',
        'text': 'لا تغير أي حرف؟',
      });
      final defaultDay = parse('سجل ملاحظة: في 2026-99-99 لم أنم');
      expect(defaultDay?.payload['date'], '2026-10-07');
      expect(defaultDay?.payload['text'], 'في 2026-99-99 لم أنم');
    },
  );

  test(
    'note and life-context headers cannot imply consent or another action',
    () {
      final action = parse(
        'save life context yesterday: medication changed tomorrow',
      );
      expect(action?.toolId, 'save_life_context');
      expect(action?.payload, {
        'date': '2026-10-06',
        'type': 'other',
        'text': 'medication changed tomorrow',
        'useInInsights': false,
      });
      expect(action?.requiresConfirmation, isTrue);
      expect(parse('سجل سياق حياتي: تغيير دواء')?.payload['type'], 'other');
      rejectAll([
        'save note tomorrow: fine',
        'save note?: fine',
        'do not save note: fine',
        'save note and close my day: fine',
        'save note yesterday today: fine',
        'save note:',
        'save note without a colon',
        'save life context and use in insights: fine',
        'save life context tomorrow: fine',
      ]);
      expect(parse('save note: ${'x' * 1001}'), isNull);
    },
  );

  test('exercise proposals name a real workout and one exact duration', () {
    final cases = <String, (String, int)>{
      'I walked for 30 minutes yesterday': ('walk', 30),
      'I ran 20 mins': ('run', 20),
      'I swam 25 minutes': ('swim', 25),
      'I cycled for 40 minutes': ('cycle', 40),
      'log a workout strength 45 minutes': ('strength', 45),
      'record exercise yoga 5 minutes': ('yoga', 5),
      'مشيت لمدة ٣٠ دقيقة': ('walk', 30),
      'تمرنت حديد ۴۵ دقيقة': ('strength', 45),
      'سجل تمرين بيلاتس ٢٠ دقيقة': ('pilates', 20),
      'log exercise upper body 30 minutes': ('upper', 30),
    };
    for (final entry in cases.entries) {
      final action = parse(entry.key);
      expect(action?.toolId, 'log_exercise', reason: entry.key);
      expect(action?.payload['workoutId'], entry.value.$1, reason: entry.key);
      expect(action?.payload['minutes'], entry.value.$2, reason: entry.key);
      expect(action?.payload.containsKey('calories'), isFalse);
      expect(action?.payload.containsKey('completed'), isFalse);
      expect(action?.requiresConfirmation, isTrue);
    }
    // Every shipped canonical workout can be selected, without new model IDs.
    for (final item in coachActivityCatalog) {
      final action = parse('log exercise ${item.id} 30 minutes');
      expect(action?.payload['workoutId'], item.id);
    }
    rejectAll([
      'log exercise walk and run 30 minutes',
      'log exercise walk 30 minutes and run 20 minutes',
      'log exercise walk 20 to 30 minutes',
      'log exercise walk 4 minutes',
      'log exercise walk 121 minutes',
      'log exercise walk 30.5 minutes',
      'log exercise something-new 30 minutes',
      'I trained 30 minutes',
      'I walked 30 minutes tomorrow',
      'log exercise walk 30 minutes, 200 calories',
    ]);
  });

  test(
    'only actual pathway IDs are proposed and consent is never inferred',
    () {
      for (final pathway in nutritionPathways) {
        final preview = parse('preview plan ${pathway.id}');
        final activate = parse('activate plan ${pathway.id}');
        expect(preview?.toolId, 'preview_plan');
        expect(preview?.type, IntelligenceActionType.readHealthData);
        expect(preview?.requiresConfirmation, isFalse);
        expect(activate?.toolId, 'activate_plan');
        expect(activate?.payload, {'pathwayId': pathway.id});
        expect(activate?.requiresConfirmation, isTrue);
        expect(
          activate?.payload.containsKey('clinicianReviewConfirmed'),
          isFalse,
        );
      }
      expect(parse('عاين خطة high-protein')?.payload, {
        'pathwayId': 'high-protein',
      });
      expect(parse('فعل خطة keto')?.payload, {'pathwayId': 'keto'});
      rejectAll([
        'preview plan high_protein',
        'activate plan not-real',
        'activate plan keto tomorrow',
        'activate plan keto yesterday',
        'activate plan keto with clinician consent',
        'activate plan keto and start fasting 16 hours',
        'activate plan keto?',
        'do not activate plan keto',
        'preview plan keto and dash',
      ]);
    },
  );

  test(
    'content search has a literal bounded query and no health write payload',
    () {
      const question = 'Sleep recovery tomorrow: ٧ ساعات؟';
      final action = parse('find health content: $question');
      expect(action?.toolId, 'search_health_content');
      expect(action?.payload, {'question': question, 'limit': 3});
      expect(action?.requiresConfirmation, isFalse);
      expect(action?.type, IntelligenceActionType.readHealthData);
      expect(parse('ابحث في المحتوى: النوم والصيام')?.payload, {
        'question': 'النوم والصيام',
        'limit': 3,
      });
      expect(
        parse('search health content: close my day')?.toolId,
        'search_health_content',
      );
      rejectAll([
        'find health content:',
        'find health content yesterday: sleep',
        'find health content sleep',
        'find health content: ${'x' * 161}',
      ]);
    },
  );

  test('health reads select one bounded topic and civil window', () {
    final cases = <String, (String, String, String)>{
      'show sleep': ('sleep', '2026-10-01', '2026-10-07'),
      'read sleep yesterday': ('sleep', '2026-10-06', '2026-10-06'),
      'view weight history last 31 days': (
        'weight',
        '2026-09-07',
        '2026-10-07',
      ),
      'show measurements for 7 days on 2026-10-05': (
        'measurements',
        '2026-09-29',
        '2026-10-05',
      ),
      'اعرض النشاط خلال اخر ٣ ايام': ('activity', '2026-10-05', '2026-10-07'),
      'اقرأ التغذية أمس': ('daily', '2026-10-06', '2026-10-06'),
      'show daily log today': ('daily', '2026-10-07', '2026-10-07'),
    };
    for (final entry in cases.entries) {
      final action = parse(entry.key);
      expect(action?.toolId, 'read_health_history', reason: entry.key);
      expect(action?.payload, {
        'topic': entry.value.$1,
        'from': entry.value.$2,
        'through': entry.value.$3,
        'limit': 31,
      }, reason: entry.key);
      expect(action?.requiresConfirmation, isFalse);
      expect(parser.recognizesHealthIntent(entry.key), isTrue);
    }
    expect(parse('show progress last 7 days')?.toolId, 'read_health_progress');
    expect(parse('اعرض تقدمي')?.payload.containsKey('topic'), isFalse);
    expect(parse('show my fasting?')?.toolId, 'read_fasting');
    rejectAll([
      'show sleep last 0 days',
      'show sleep last 32 days',
      'show sleep and weight',
      'show sleep last 3 weeks',
      'show sleep from 2026-10-01 to 2026-10-07',
      'show sleep tomorrow',
      'show sleep last 7 days and last 3 days',
    ]);
  });

  test(
    'date arithmetic remains calendar based across spring and autumn DST',
    () {
      if (Platform.environment['TZ'] == 'America/New_York') {
        expect(
          DateTime(2026, 3, 9).difference(DateTime(2026, 3, 8)).inHours,
          23,
        );
        expect(
          DateTime(2026, 11, 2).difference(DateTime(2026, 11, 1)).inHours,
          25,
        );
      }
      for (final (date, expectedFrom) in [
        (DateTime(2026, 3, 10, 12), '2026-03-04'),
        (DateTime(2026, 11, 3, 12), '2026-10-28'),
      ]) {
        final action = parser.parse(
          'show sleep for 7 days',
          locale: 'en',
          referenceLocal: date,
        );
        expect(action?.payload['from'], expectedFrom);
      }
      final spring = parser.parse(
        'log sleep 7 hours yesterday',
        locale: 'en',
        referenceLocal: DateTime(2026, 3, 9, 0, 15),
      );
      expect(spring?.payload['date'], '2026-03-08');
      final autumn = parser.parse(
        'close my day yesterday',
        locale: 'en',
        referenceLocal: DateTime(2026, 11, 2, 0, 15),
      );
      expect(autumn?.payload['date'], '2026-11-01');
    },
  );

  test(
    'routing leaves existing food, water, weight-write and navigation alone',
    () {
      for (final input in [
        'log water 500 ml',
        'I drank 250 ml water',
        'سجل ماء ٥٠٠ مل',
        'log weight 70 kg',
        'I weigh 70 kg',
        'سجل وزني ٧٠ كيلو',
        'add 300 calories',
        'I ate 150 g chicken',
        'سجل ٣٠٠ سعرة',
        'open workouts',
        'open sleep',
        'open weight history',
        'go to nutrition',
        'what is sleep?',
        'مرحبا',
      ]) {
        expect(parser.recognizesHealthIntent(input), isFalse, reason: input);
        expect(parse(input), isNull, reason: input);
      }
      expect(parse(''), isNull);
      expect(parse('x' * 1601), isNull);
    },
  );
}
