import 'package:flutter/material.dart';

import 'auth_five_locale_copy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/services/app_settings_provider.dart';
import '../../app/localization/bil_locale_names.dart';
import '../../app/localization/bil_locale_policy.dart';

class AuthLanguageSelector extends ConsumerWidget {
  const AuthLanguageSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(appSettingsProvider).localeCode;
    const languages = BilLocaleNames.native;
    return Semantics(
      label: authFiveLocaleTextFor(selected, 'Choose language', 'اختيار اللغة'),
      child: PopupMenuButton<String>(
        key: const Key('auth-language-selector'),
        tooltip: authFiveLocaleTextFor(
          selected,
          'Choose language',
          'اختيار اللغة',
        ),
        initialValue: selected,
        onSelected: (value) {
          ref.read(appSettingsProvider.notifier).setLocale(value);
        },
        itemBuilder: (context) => languages.entries
            .map(
              (entry) => PopupMenuItem<String>(
                value: entry.key,
                child: Row(
                  children: [
                    if (entry.key == selected)
                      const Icon(Icons.check_rounded, size: 18)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 10),
                    Text(
                      entry.value,
                      style: const TextStyle(fontFamilyFallback: ['BILArabic']),
                    ),
                  ],
                ),
              ),
            )
            .toList(growable: false),
        child: Directionality(
          textDirection: BilLocalePolicy.isRtlTag(selected)
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE3E6E9),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF68727C), width: 1.1),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.language_rounded,
                    size: 14,
                    color: Color(0xFF303942),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    languages[selected] ?? languages['en']!,
                    textDirection: BilLocalePolicy.isRtlTag(selected)
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF252D34),
                      fontWeight: FontWeight.w600,
                      fontFamilyFallback: const ['BILArabic'],
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 15,
                    color: Color(0xFF303942),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
