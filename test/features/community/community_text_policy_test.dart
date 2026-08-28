import 'dart:io';

import 'package:body_intelligence_log/features/community/domain/community_text_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommunityTextPolicy blocks contact exchange', () {
    final blocked = <String, CommunityTextViolationKind>{
      'email me at member@example.com': CommunityTextViolationKind.email,
      'visit https://example.com/profile':
          CommunityTextViolationKind.urlOrDomain,
      'my page is example.co': CommunityTextViolationKind.urlOrDomain,
      'find me @health_friend': CommunityTextViolationKind.socialHandle,
      'تواصل معي على @صديق_الصحة': CommunityTextViolationKind.socialHandle,
      'call +20 100 123 4567': CommunityTextViolationKind.phoneNumber,
      'call (415) 555-2671': CommunityTextViolationKind.phoneNumber,
      'رقمي ٠١٠ ١٢٣٤ ٥٦٧٨': CommunityTextViolationKind.phoneNumber,
      'شماره ۰۹۱۲-۳۴۵-۶۷۸۹': CommunityTextViolationKind.phoneNumber,
      'नंबर ९८७६५ ४३२१०': CommunityTextViolationKind.phoneNumber,
      'নম্বর ০১৭১২-৩৪৫৬৭৮': CommunityTextViolationKind.phoneNumber,
      '番号 ０９０-１２３４-５６７８': CommunityTextViolationKind.phoneNumber,
      'message me on WhatsApp':
          CommunityTextViolationKind.offPlatformInvitation,
      'Telegram me and we can continue there':
          CommunityTextViolationKind.offPlatformInvitation,
      'راسلني على واتساب': CommunityTextViolationKind.offPlatformInvitation,
      'escríbeme por Instagram':
          CommunityTextViolationKind.offPlatformInvitation,
      'Telegram üzerinden bana yaz':
          CommunityTextViolationKind.offPlatformInvitation,
      'मुझे व्हाट्सएप पर संदेश भेजें':
          CommunityTextViolationKind.offPlatformInvitation,
      '微信联系我': CommunityTextViolationKind.offPlatformInvitation,
      'schreib mir auf Telegram':
          CommunityTextViolationKind.offPlatformInvitation,
      'напиши мне в Signal': CommunityTextViolationKind.offPlatformInvitation,
      'move this conversation outside BIL':
          CommunityTextViolationKind.offPlatformInvitation,
    };

    for (final entry in blocked.entries) {
      test(entry.key, () {
        expect(CommunityTextPolicy.firstViolation(entry.key), entry.value);
      });
    }
  });

  test(
    'normal health, nutrition, exercise, and date numbers remain allowed',
    () {
      const allowed = <String>[
        'My target is 1800 kcal and 120 g protein.',
        'Current weight is 89.2 kg.',
        'I walked 10,000 steps and ran 10.5 km.',
        'Vitamin B12 is 1000 mcg and sodium is 2300 mg.',
        'Progress check: 2026-08-24.',
        'Progress check: 20260824.',
        'موعد القياس ٢٠٢٦-٠٨-٢٤ والوزن ٨٩٫٢ كجم.',
        'वजन ८९.२ kg और लक्ष्य १८०० kcal है।',
        'Heart rate was 72 bpm during 3 sets of 12 reps.',
        'I disabled WhatsApp notifications to focus on my workout.',
        'Message me here in BIL about the meal plan.',
        'At home @ 7 I prepared dinner.',
      ];

      for (final value in allowed) {
        expect(
          CommunityTextPolicy.firstViolation(value),
          isNull,
          reason: value,
        );
      }
    },
  );

  test('all publishable surfaces throw the same reviewable error code', () {
    for (final surface in CommunityTextSurface.values) {
      expect(
        () => CommunityTextPolicy.enforce(
          'contact me at person@example.org',
          surface: surface,
        ),
        throwsA(
          isA<CommunityTextPolicyException>()
              .having((error) => error.surface, 'surface', surface)
              .having(
                (error) => error.toString(),
                'stable code',
                contains(CommunityTextPolicy.errorCode),
              ),
        ),
      );
    }
  });

  test('privacy error has direct copy for every production locale', () {
    const expectedTags = <String>{
      'ar',
      'en',
      'fr',
      'es',
      'tr',
      'de',
      'it',
      'pt-BR',
      'pt-PT',
      'ur',
      'fa',
      'hi',
      'id',
      'ms',
      'ja',
      'ko',
      'zh-Hans',
      'zh-Hant',
      'ru',
      'bn',
      'vi',
      'th',
      'pl',
      'nl',
      'uk',
    };
    expect(CommunityTextPolicy.localizedMessages.keys.toSet(), expectedTags);
    const error = CommunityTextPolicyException(
      surface: CommunityTextSurface.message,
      kind: CommunityTextViolationKind.email,
    );
    for (final tag in expectedTags) {
      expect(error.localizedMessage(tag), isNotEmpty, reason: tag);
      if (tag == 'en') {
        expect(error.localizedMessage(tag), error.localizedMessage('xx'));
      } else {
        expect(
          error.localizedMessage(tag),
          isNot(error.localizedMessage('xx')),
          reason: tag,
        );
      }
    }
  });

  test('client guards every Community UGC write before network dispatch', () {
    final repository = File(
      'lib/features/community/data/community_repository.dart',
    ).readAsStringSync();
    final postStore = File(
      'lib/features/community/data/community_post_cloud_store.dart',
    ).readAsStringSync();
    final communityFoodGateway = File(
      'lib/features/nutrition/community_catalog/data/supabase_community_food_catalog.dart',
    ).readAsStringSync();

    for (final method in const [
      'saveMyProfile',
      'sendMessage',
      'reviewFood',
      'submitFood',
      'submitProductReview',
    ]) {
      final start = repository.indexOf(method);
      expect(start, greaterThanOrEqualTo(0), reason: method);
      final proposedEnd = start + 2200;
      final end = proposedEnd < repository.length
          ? proposedEnd
          : repository.length;
      expect(
        repository.substring(start, end),
        contains('CommunityTextPolicy.enforce'),
        reason: method,
      );
    }
    expect(postStore, contains('CommunityTextSurface.post'));
    expect(communityFoodGateway, contains('CommunityTextPolicy.enforceAll'));
    expect(communityFoodGateway, contains("payload['aliases']"));
  });

  test('database trigger protects every persisted public text surface', () {
    final sql = File(
      'supabase/migrations/202608240002_community_contact_exchange_policy.sql',
    ).readAsStringSync().toLowerCase();

    expect(sql, contains('community_contact_exchange_not_allowed'));
    expect(sql, contains("errcode = 'p0001'"));
    expect(sql, contains('security invoker'));
    expect(sql, contains('before insert or update of display_name, bio'));
    expect(sql, contains('before insert or update of body'));
    expect(
      RegExp('before insert or update of body').allMatches(sql),
      hasLength(2),
    );
    expect(
      sql,
      contains(
        'before insert or update of canonical_name, localized_names, aliases, brand, review_note',
      ),
    );
    expect(sql, contains('before insert or update of note'));
    expect(sql, contains('jsonb_each_text'));
    expect(sql, contains('jsonb_array_elements_text'));
    expect(sql, isNot(contains('evidence_url')));
  });

  test('publish screens show the localized policy message', () {
    for (final path in const [
      'lib/features/community/presentation/community_feed_tab.dart',
      'lib/features/community/presentation/community_food_tab.dart',
      'lib/features/community/presentation/community_chat_page.dart',
      'lib/features/community/presentation/community_messages_page.dart',
      'lib/features/community/presentation/community_profile_page.dart',
      'lib/features/community/presentation/product_review_submission_dialog.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains('on CommunityTextPolicyException catch (error)'),
        reason: path,
      );
      expect(source, contains('error.localizedMessage('), reason: path);
    }
  });
}
