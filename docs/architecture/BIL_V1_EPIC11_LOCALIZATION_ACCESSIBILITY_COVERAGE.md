# BIL v1 Epic 11 — localization and accessibility closure

Production locales are Arabic, English, French, Spanish, and Turkish. Arabic
is RTL; all other production locales are LTR. The first launch follows the
device locale when supported and otherwise uses English. Changing language is
stored independently from authentication, onboarding, and health records.

The typed base catalog, feature catalog, and reviewed runtime migration catalog
must remain key-balanced. Debug builds assert on missing production copy;
release surfaces a localized unavailable message rather than exposing a key or
silently substituting English. The release audit is still required to pass, so
that safe boundary cannot conceal missing production copy.

Locale formatting uses `intl` for numbers, dates, time, and plurals. Mixed
identifiers can be wrapped with Unicode bidi isolation. Store prices remain
store-provided strings and units/brands are not translated incorrectly.

Native permission copy is present for all five locales on Android and iOS.
System fonts, padded Material targets, SafeArea, system text scaling, visible
focus, high contrast, and reduced motion remain the application defaults.
Widget tests cover RTL/LTR, 200% text scale, semantics, minimum interaction
size, persisted language choice, light/dark infrastructure, and five locale
goldens.

External gates remain: professional human linguistic review in all five
languages; TalkBack on physical Android; VoiceOver and Dynamic Type on physical
iPhone; keyboard traversal on supported desktop targets; and manual WCAG 2.2 AA
contrast review of generated/remote imagery. These gates do not represent
missing strings and must not be claimed complete without device evidence.
