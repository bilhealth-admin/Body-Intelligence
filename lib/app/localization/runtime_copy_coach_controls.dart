import 'bil_locale_policy.dart';

part 'runtime_copy_coach_controls_0.dart';
part 'runtime_copy_coach_controls_1.dart';
part 'runtime_copy_coach_controls_2.dart';
part 'runtime_copy_coach_controls_3.dart';

/// Authored Coach controls, history and existing consent copy in all 25 locales.
abstract final class CoachControlsRuntimeCopy {
  static const sources = <String>[
    "App appearance updated.",
    "App language updated.",
    "Ask before write",
    "BIL uses Google Gemini, a third-party AI service operated by Google, only to generate the answer you request.",
    "Conversation",
    "Conversation history is stored locally on this device.",
    "Conversations",
    "Current conversation",
    "End live call",
    "Food photo",
    "Keep this chat in history and start an empty one.",
    "New conversation",
    "No previous conversations yet.",
    "Only the context you choose",
    "Raw microphone audio is not sent",
    "Read only",
    "Sending",
    "Signed out successfully.",
    "The pending action was cancelled. Nothing was changed.",
    "The previous action was undone.",
    "There is no recent reversible action.",
    "This action needs write permission. Change the shield setting to continue.",
    "Voice recognition stays separate from this Remote AI consent.",
    "Write allowed",
    "You can decline and keep using local BIL features, or withdraw this consent later in AI Coach settings.",
    "You stay in control",
    "Your question; selected weight, goals and measurements; meals, nutrition, water and preferences; activity and training; sleep and habits; plus up to 12 recent conversation turns.",
    "The action was not completed. Your data stayed unchanged; review the value and try again.",
  ];
  static const rows = <String, List<String>>{
    'en': sources,
    ..._coachControlsRows0,
    ..._coachControlsRows1,
    ..._coachControlsRows2,
    ..._coachControlsRows3,
  };

  static String? resolve(String source, String localeTag) {
    final index = sources.indexOf(source);
    if (index < 0) return null;
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag);
    final row = rows[tag];
    if (row == null) return null;
    if (row.length != sources.length) {
      throw StateError('Incomplete Coach controls copy for $tag');
    }
    return row[index];
  }
}
