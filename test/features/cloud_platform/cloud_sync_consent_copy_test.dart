import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('benefit-led consent copy stays truthful and non-coercive', () {
    expect(CloudSyncConsentCopy.settingsTitle, 'Progress backup');
    expect(CloudSyncConsentCopy.title, 'Take your progress with you');
    expect(
      CloudSyncConsentCopy.title.toLowerCase().startsWith('cloud'),
      isFalse,
    );
    expect(
      CloudSyncConsentCopy.restoreBenefit,
      allOf(
        contains('profile'),
        contains('weight'),
        contains('water'),
        contains('reinstalling BIL'),
        contains('new phone'),
      ),
    );
    expect(
      CloudSyncConsentCopy.continuityBenefit,
      allOf(contains('records'), contains('signed-in devices')),
    );
    expect(
      CloudSyncConsentCopy.privacyBenefit,
      allOf(
        contains('Encrypted before upload'),
        contains('private to your account'),
        contains('Other users cannot see it'),
        contains('does not sell your data'),
      ),
    );
    expect(
      CloudSyncConsentCopy.localNutrition,
      allOf(
        contains('only your profile, weight and water'),
        contains('Nutrition and goal backups are separate choices in Privacy'),
      ),
    );
    expect(
      CloudSyncConsentCopy.choiceControl,
      'You can change this choice anytime in Privacy.',
    );
    expect(
      CloudSyncConsentCopy.deletionControl,
      allOf(contains('request deletion'), contains('saved cloud copy')),
    );
    expect(
      CloudSyncConsentCopy.settingsSubtitle,
      'Restore and continue your profile, weight and water.',
    );
    expect(
      CloudSyncConsentCopy.manageCategoriesAction,
      'Manage backup categories',
    );
    expect(CloudSyncConsentCopy.primaryAction, contains('sync'));
    expect(CloudSyncConsentCopy.localAction, contains('on this device'));
    expect(
      CloudSyncConsentCopy.sources.join(' ').toLowerCase(),
      isNot(contains('all data')),
    );
  });

  test(
    'all 25 locales name the base data and distinguish separate Nutrition and Goals choices',
    () {
      const requiredScopeTerms = <String, List<String>>{
        'en': [
          'profile',
          'weight',
          'water',
          'only',
          'nutrition',
          'goal',
          'separate',
          'privacy',
        ],
        'ar': [
          'ملفك الشخصي',
          'وزنك',
          'سجلات الماء',
          'فقط',
          'التغذية',
          'الأهداف',
          'منفصلان',
          'الخصوصية',
        ],
        'fr': [
          'profil',
          'poids',
          'eau',
          'uniquement',
          'nutrition',
          'objectifs',
          'distincts',
          'confidentialité',
        ],
        'es': [
          'perfil',
          'peso',
          'agua',
          'solo',
          'nutrición',
          'objetivos',
          'separado',
          'privacidad',
        ],
        'tr': [
          'profil',
          'kilo',
          'su',
          'yalnızca',
          'beslenme',
          'hedef',
          'ayrı',
          'gizlilik',
        ],
        'de': [
          'profil',
          'gewicht',
          'wasser',
          'nur',
          'ernährung',
          'ziele',
          'separate',
          'datenschutz',
        ],
        'it': [
          'profilo',
          'peso',
          'acqua',
          'solo',
          'nutrizione',
          'obiettivi',
          'separate',
          'privacy',
        ],
        'pt-BR': [
          'perfil',
          'peso',
          'água',
          'apenas',
          'nutrição',
          'metas',
          'separadas',
          'privacidade',
        ],
        'pt-PT': [
          'perfil',
          'peso',
          'água',
          'apenas',
          'nutrição',
          'objetivos',
          'separadas',
          'privacidade',
        ],
        'ur': [
          'پروفائل',
          'وزن',
          'پانی',
          'صرف',
          'غذائیت',
          'اہداف',
          'الگ',
          'رازداری',
        ],
        'fa': [
          'نمایه',
          'وزن',
          'آب',
          'فقط',
          'تغذیه',
          'اهداف',
          'جداگانه',
          'حریم خصوصی',
        ],
        'hi': [
          'प्रोफ़ाइल',
          'वज़न',
          'पानी',
          'केवल',
          'पोषण',
          'लक्ष्यों',
          'अलग-अलग',
          'गोपनीयता',
        ],
        'id': [
          'profil',
          'berat',
          'air',
          'hanya',
          'nutrisi',
          'target',
          'terpisah',
          'privasi',
        ],
        'ms': [
          'profil',
          'berat',
          'air',
          'hanya',
          'pemakanan',
          'matlamat',
          'berasingan',
          'privasi',
        ],
        'ja': ['プロフィール', '体重', '水分', 'のみ', '栄養', '目標', '別に', 'プライバシー'],
        'ko': ['프로필', '체중', '수분', '만', '영양', '목표', '별도로', '개인정보 보호'],
        'zh-Hans': ['个人资料', '体重', '饮水', '仅', '营养', '目标', '分别', '隐私'],
        'zh-Hant': ['個人資料', '體重', '飲水', '僅', '營養', '目標', '分別', '隱私'],
        'ru': [
          'профиль',
          'веса',
          'воды',
          'только',
          'питания',
          'целей',
          'отдельно',
          'конфиденциальность',
        ],
        'bn': [
          'প্রোফাইল',
          'ওজন',
          'পানির',
          'শুধু',
          'পুষ্টি',
          'লক্ষ্যের',
          'আলাদা',
          'গোপনীয়তায়',
        ],
        'vi': [
          'hồ sơ',
          'cân nặng',
          'nước',
          'chỉ',
          'dinh dưỡng',
          'mục tiêu',
          'riêng',
          'quyền riêng tư',
        ],
        'th': [
          'โปรไฟล์',
          'น้ำหนัก',
          'ดื่มน้ำ',
          'เฉพาะ',
          'โภชนาการ',
          'เป้าหมาย',
          'แยกกัน',
          'ความเป็นส่วนตัว',
        ],
        'pl': [
          'profilu',
          'wagi',
          'wody',
          'tylko',
          'żywieniowych',
          'celów',
          'osobne',
          'prywatność',
        ],
        'nl': [
          'profiel',
          'gewicht',
          'water',
          'alleen',
          'voeding',
          'doelen',
          'afzonderlijke',
          'privacy',
        ],
        'uk': [
          'профіль',
          'ваги',
          'води',
          'лише',
          'харчування',
          'цілей',
          'окремі',
          'конфіденційність',
        ],
      };
      expect(requiredScopeTerms.keys.toSet(), CloudSyncConsentCopy.supported);
      for (final entry in requiredScopeTerms.entries) {
        final text = RuntimeCopy.resolve(
          CloudSyncConsentCopy.localNutrition,
          entry.key,
        )!.toLowerCase();
        for (final term in entry.value) {
          expect(
            text,
            contains(term),
            reason: 'Precise backup scope missing for ${entry.key}: $term',
          );
        }
      }
    },
  );

  test('all twelve consent messages resolve natively across 25 locales', () {
    final shipped = AppLocalizations.supportedLocales
        .map(BilLocalePolicy.canonicalTag)
        .toSet();
    expect(shipped, hasLength(25));
    expect(CloudSyncConsentCopy.supported, shipped);
    expect(CloudSyncConsentCopy.balanced, isTrue);
    expect(CloudSyncConsentCopy.sources, hasLength(12));

    for (final locale in shipped) {
      for (final source in CloudSyncConsentCopy.sources) {
        final translated = RuntimeCopy.resolve(source, locale);
        expect(
          translated,
          isNotNull,
          reason: 'Missing cloud consent copy for $locale: $source',
        );
        expect(translated!.trim(), isNotEmpty);
        expect(translated, isNot(contains('\uFFFD')));
        if (locale != 'en') {
          expect(
            translated,
            isNot(source),
            reason: 'Unreviewed English fallback for $locale: $source',
          );
        }
      }
    }
  });
}
