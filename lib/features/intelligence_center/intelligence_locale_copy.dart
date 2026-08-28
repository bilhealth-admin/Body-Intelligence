import 'package:flutter/widgets.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/localization/bil_locale_policy.dart';
import '../../app/localization/runtime_copy.dart';

part 'intelligence_service_locale_copy.dart';
part 'intelligence_ui_locale_copy.dart';

String intelligenceText(BuildContext context, String english, String arabic) =>
    intelligenceTextFor(
      BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
      english,
      arabic,
    );

String intelligenceTextFor(String localeTag, String english, String arabic) {
  final normalized = localeTag.replaceAll('_', '-');
  final code = normalized.toLowerCase().split('-').first;
  if (code == 'ar') return arabic;
  final authored =
      _authored[english]?[code] ?? _serviceAuthored[english]?[code];
  if (authored != null) return authored;
  final exact = RuntimeCopy.resolve(english, normalized);
  if (exact != null) return exact;
  return AppLocalizations(
    BilLocalePolicy.localeFromTag(normalized),
  ).text(english);
}
