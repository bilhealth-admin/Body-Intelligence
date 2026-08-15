import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/bil_locale_names.dart';
import '../../app/localization/bil_locale_policy.dart';
import '../../app/localization/app_localizations.dart';
import '../../app/services/app_settings_provider.dart';

class LanguageSettingsPage extends ConsumerWidget {
  const LanguageSettingsPage({super.key});

  static const orderedTags = <String>[
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
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(appSettingsProvider).localeCode;
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.text('Language'))),
      body: ListView.builder(
        itemCount: orderedTags.length,
        itemBuilder: (context, index) {
          final tag = orderedTags[index];
          return Directionality(
            textDirection: BilLocalePolicy.isRtlTag(tag)
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: ListTile(
              key: Key('language-option-$tag'),
              minTileHeight: 58,
              title: Text(BilLocaleNames.native[tag]!),
              trailing: selected == tag
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () =>
                  ref.read(appSettingsProvider.notifier).setLocale(tag),
            ),
          );
        },
      ),
    );
  }
}
