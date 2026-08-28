import 'package:flutter/widgets.dart';

part 'auth_entry_locale_copy_group_a.dart';
part 'auth_entry_locale_copy_group_b.dart';
part 'auth_entry_locale_copy_group_c.dart';

enum AuthEntryCopyKey {
  chooseLanguage,
  welcomeTo,
  signIn,
  continueWithoutAccount,
  taglineTitle,
  taglineBody,
  progressTitle,
  progressBody,
  rhythmTitle,
  rhythmBody,
  nutritionTitle,
  nutritionBody,
  privacyFooter,
  cloudNotEnabled,
  restorePreviousData,
  restorePreviousDataQuestion,
  restoreDialogBody,
  cancel,
  restore,
  back,
  emailAddress,
  invalidEmail,
  verify,
  orLabel,
  continueGoogle,
  continueApple,
  continueFacebook,
  privacyPolicy,
  providerUnavailable,
  openSecureFailure,
  secureConnectionFailure,
  verifyEmail,
  enterVerificationCode,
  codeSentTo,
  codeVerificationFailed,
  newCodeSent,
  resendFailed,
  resendCode,
  resendCodeIn,
  changeEmail,
  rateLimit60,
  verificationExpired,
  signupUnavailable,
  authenticationFailed,
}

/// Explicit copy for every locale declared by [BilLocaleNames.native].
///
/// There is deliberately no English fallback for a declared locale: missing
/// copy is a test failure so production cannot silently ship mixed-language
/// authentication or OTP screens.
const authEntryAuthoredLocaleTags = <String>[
  "ar",
  "en",
  "fr",
  "es",
  "tr",
  "de",
  "it",
  "pt-BR",
  "pt-PT",
  "ur",
  "fa",
  "hi",
  "id",
  "ms",
  "ja",
  "ko",
  "zh-Hans",
  "zh-Hant",
  "ru",
  "bn",
  "vi",
  "th",
  "pl",
  "nl",
  "uk",
];

String authEntryText(BuildContext context, AuthEntryCopyKey key) =>
    authEntryTextForTag(Localizations.localeOf(context).toLanguageTag(), key);

String authEntryTextForTag(String localeTag, AuthEntryCopyKey key) {
  final localeKey = _canonicalLocaleTag(localeTag);
  final localized = _authEntryCopy[localeKey]?[key];
  assert(
    localized != null,
    'Missing auth entry copy for locale $localeKey and key $key',
  );
  return localized ?? _authEntryCopy['en']![key]!;
}

bool authEntryHasExactLocale(String localeTag) =>
    _authEntryCopy.containsKey(_canonicalLocaleTag(localeTag));

bool authEntryHasExactCopy(String localeTag, AuthEntryCopyKey key) =>
    _authEntryCopy[_canonicalLocaleTag(localeTag)]?.containsKey(key) ?? false;

String authEntryCodeSent(BuildContext context, String email) => _format(
  authEntryText(context, AuthEntryCopyKey.codeSentTo),
  <String, String>{'email': email},
);

String authEntryResendCountdown(BuildContext context, String clock) => _format(
  authEntryText(context, AuthEntryCopyKey.resendCodeIn),
  <String, String>{'time': clock},
);

String authEntryCodeSentForTag(String localeTag, String email) => _format(
  authEntryTextForTag(localeTag, AuthEntryCopyKey.codeSentTo),
  <String, String>{'email': email},
);

String authEntryResendCountdownForTag(String localeTag, String clock) =>
    _format(
      authEntryTextForTag(localeTag, AuthEntryCopyKey.resendCodeIn),
      <String, String>{'time': clock},
    );

String _canonicalLocaleTag(String localeTag) {
  final normalized = localeTag.trim().replaceAll('_', '-').toLowerCase();
  if (normalized.isEmpty) return 'en';
  return switch (normalized) {
    'pt-br' => 'pt-BR',
    'pt-pt' => 'pt-PT',
    'zh-hans' => 'zh-Hans',
    'zh-hant' => 'zh-Hant',
    _ => normalized.split('-').first,
  };
}

String _format(String template, Map<String, String> values) {
  var result = template;
  for (final entry in values.entries) {
    result = result.replaceAll('{${entry.key}}', entry.value);
  }
  return result;
}

const _authEntryCopy = <String, Map<AuthEntryCopyKey, String>>{
  ..._authEntryCopyGroupA,
  ..._authEntryCopyGroupB,
  ..._authEntryCopyGroupC,
};
