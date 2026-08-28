import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/bil_locale_names.dart';
import '../../app/localization/bil_locale_policy.dart';
import '../../app/localization/app_localizations.dart';
import '../../app/services/app_settings_provider.dart';

class LanguageSettingsPage extends ConsumerWidget {
  const LanguageSettingsPage({super.key});

  static const orderedTags = BilLocaleNames.englishFirstAlphabeticalTags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(appSettingsProvider).localeCode;
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.text('Language'))),
      body: ListView.builder(
        itemCount: orderedTags.length,
        itemBuilder: (context, index) {
          final tag = orderedTags[index];
          final optionDirection = BilLocalePolicy.isRtlTag(tag)
              ? TextDirection.rtl
              : TextDirection.ltr;
          return Directionality(
            textDirection: TextDirection.ltr,
            child: ListTile(
              key: Key('language-option-$tag'),
              minTileHeight: 58,
              title: Text(
                BilLocaleNames.native[tag]!,
                locale: BilLocalePolicy.localeFromTag(tag),
                textDirection: optionDirection,
                textAlign: TextAlign.left,
              ),
              trailing: selected == tag
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () async {
                await ref.read(appSettingsProvider.notifier).setLocale(tag);
                if (context.mounted && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            ),
          );
        },
      ),
    );
  }
}
