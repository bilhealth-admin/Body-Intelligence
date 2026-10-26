part of 'bil_smart_plan_page.dart';

Color _smartPlanActionInk(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
    ? BilFlagshipTokens.navy800
    : Theme.of(context).colorScheme.primary;

String _smartPlanText(BuildContext context, String english, String arabic) {
  final tag = BilLocalePolicy.canonicalTag(Localizations.localeOf(context));
  if (tag == 'ar') return arabic;
  if (tag == 'en') return english;
  final translated = RuntimeCopy.resolve(english, tag);
  if (translated == null) return english;
  // Sentence fragments surround measured values; preserve their spacing even
  // when a translated catalogue entry has been trimmed by its provider.
  final leading = RegExp(r'^\s*').firstMatch(english)!.group(0)!;
  final trailing = RegExp(r'\s*$').firstMatch(english)!.group(0)!;
  return '$leading${translated.trim()}$trailing';
}
