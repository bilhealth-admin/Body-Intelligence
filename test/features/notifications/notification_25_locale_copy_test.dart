import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/notifications/domain/daily_reminder.dart';
import 'package:body_intelligence_log/features/notifications/services/bil_notification_service.dart';
import 'package:body_intelligence_log/features/notifications/services/notification_extended_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'all 25 shipped locales have non-English background notification copy',
    () {
      expect(bilExtendedNotificationCopyIsComplete, isTrue);
      expect(bilSleepScheduleLabelsAreComplete, isTrue);
      for (final locale in AppLocalizations.supportedLocales) {
        final tag = locale.toLanguageTag();
        final scheduleLabels = bilSleepScheduleLabels(tag);
        expect(scheduleLabels.$1.trim(), isNotEmpty, reason: '$tag bedtime');
        expect(scheduleLabels.$2.trim(), isNotEmpty, reason: '$tag wake time');
        if (locale.languageCode != 'en') {
          expect(
            scheduleLabels,
            isNot(equals(bilSleepScheduleLabels('en'))),
            reason: '$tag sleep labels fell back to English',
          );
        }
        for (final kind in BilBackgroundCopyKind.values) {
          final copy = bilBackgroundCopyForTesting(tag, kind);
          expect(copy.$1.trim(), isNotEmpty, reason: '$tag $kind title');
          expect(copy.$2.trim(), isNotEmpty, reason: '$tag $kind body');
          if (locale.languageCode != 'en') {
            final english = bilBackgroundCopyForTesting('en', kind);
            expect(
              copy,
              isNot(equals(english)),
              reason: '$tag $kind fell back to English',
            );
          }
        }
        for (final kind in DailyReminderKind.values) {
          final copy = bilDailyReminderCopyForTesting(tag, kind);
          expect(copy.$1.trim(), isNotEmpty, reason: '$tag $kind title');
          expect(copy.$2.trim(), isNotEmpty, reason: '$tag $kind body');
          if (locale.languageCode != 'en') {
            final english = bilDailyReminderCopyForTesting('en', kind);
            expect(
              copy,
              isNot(equals(english)),
              reason: '$tag $kind fell back to English',
            );
          }
        }
        final sleepCopy = bilSleepScheduleCopyForTesting(tag);
        expect(sleepCopy, hasLength(3));
        expect(
          sleepCopy.every(
            (copy) => copy.$1.trim().isNotEmpty && copy.$2.trim().isNotEmpty,
          ),
          isTrue,
          reason: '$tag sleep schedule copy',
        );
        if (locale.languageCode != 'en') {
          expect(
            sleepCopy,
            isNot(equals(bilSleepScheduleCopyForTesting('en'))),
            reason: '$tag sleep schedule fell back to English',
          );
        }
      }
    },
  );
}
