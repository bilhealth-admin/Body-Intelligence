import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/bil_locale_names.dart';
import '../../app/localization/bil_locale_policy.dart';
import '../../app/services/app_settings_provider.dart';
import 'auth_entry_locale_copy.dart';

class AuthLanguageSelector extends ConsumerWidget {
  const AuthLanguageSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configured = ref.watch(appSettingsProvider).localeCode;
    const languages = BilLocaleNames.native;
    final selected = _effectiveLocaleTag(configured, languages);
    final label = authEntryTextForTag(
      selected,
      AuthEntryCopyKey.chooseLanguage,
    );
    final displayedLanguage = languages[selected] ?? languages['en']!;

    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('auth-language-selector'),
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showLanguageSheet(
            context: context,
            ref: ref,
            selected: selected,
          ),
          child: Container(
            constraints: const BoxConstraints(minWidth: 118, maxWidth: 250),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x09000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                key: const Key('auth-language-selector-row'),
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      displayedLanguage,
                      key: const Key('auth-language-selector-label'),
                      locale: BilLocalePolicy.localeFromTag(selected),
                      textDirection: BilLocalePolicy.isRtlTag(selected)
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF1C1C1E),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        fontFamilyFallback: ['BILArabic'],
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Icon(
                    key: Key('auth-language-selector-arrow'),
                    Icons.keyboard_arrow_down_rounded,
                    size: 17,
                    color: Color(0xFF8E8E93),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showLanguageSheet({
    required BuildContext context,
    required WidgetRef ref,
    required String selected,
  }) async {
    const languages = BilLocaleNames.native;
    const orderedKeys = BilLocaleNames.englishFirstAlphabeticalTags;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x52000000),
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .72,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 30,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D1D6),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  authEntryTextForTag(
                    selected,
                    AuthEntryCopyKey.chooseLanguage,
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF1C1C1E),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.25,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFE9E9ED)),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
                  itemCount: orderedKeys.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    indent: 14,
                    endIndent: 14,
                    color: Color(0xFFF0F0F3),
                  ),
                  itemBuilder: (context, index) {
                    final key = orderedKeys[index];
                    final isSelected = key == selected;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          await ref
                              .read(appSettingsProvider.notifier)
                              .setLocale(key);
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Row(
                              key: Key('auth-language-option-row-$key'),
                              children: [
                                Expanded(
                                  child: Text(
                                    languages[key]!,
                                    key: Key('auth-language-option-label-$key'),
                                    locale: BilLocalePolicy.localeFromTag(key),
                                    textDirection: BilLocalePolicy.isRtlTag(key)
                                        ? TextDirection.rtl
                                        : TextDirection.ltr,
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      color: const Color(0xFF1C1C1E),
                                      fontSize: 16,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      fontFamilyFallback: const ['BILArabic'],
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    key: Key('auth-language-option-check'),
                                    Icons.check_rounded,
                                    size: 20,
                                    color: Color(0xFF007AFF),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _effectiveLocaleTag(String configured, Map<String, String> languages) {
  final canonical = BilLocalePolicy.canonicalSupportedTag(configured);
  if (canonical != null && languages.containsKey(canonical)) return canonical;
  return 'en';
}
