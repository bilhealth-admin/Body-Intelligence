import 'bil_locale_policy.dart';

part 'runtime_copy_next_workspace_0.dart';
part 'runtime_copy_next_workspace_1.dart';
part 'runtime_copy_next_workspace_2.dart';
part 'runtime_copy_next_workspace_3.dart';
part 'runtime_copy_next_workspace_supplemental_0.dart';
part 'runtime_copy_next_workspace_supplemental_1.dart';

/// Authored next-version workspace and inbox copy; all locale rows are tested.
abstract final class NextWorkspaceRuntimeCopy {
  static const _primarySources = <String>[
    "Could not confirm these updates as read. Please retry.",
    "Mark this page read",
    "Let's make today count.",
    "Today's Focus",
    "One small action at a time. Your coach is here to help you log, reflect, and plan.",
    "Plan Tools",
    "Log a Meal",
    "Voice Log",
    "Just talk",
    "In seconds",
    "Scan Product",
    "Barcode / Label",
    "Turn any meal into insights",
    "Snap a photo to review food and portions before adding it to your log.",
    "Try Photo Logging  ›",
    "Your Health Timeline",
    "Meals logged",
    "{count} meal entries in your actual log",
    "Activity synced",
    "Your verified entries will appear here.",
    "Small consistent actions create meaningful progress.\n— BIL AI Coach",
    "Your health partner, always with you",
    "Search conversations",
  ];
  static const supplementalSources = [
    'Overview',
    'Post photos',
    'Home',
    'Private unfinished posts',
    'Save profile and create BIL Code',
    'Sign in to open your private drafts.',
    'Coach action permissions',
    'Stats',
    "{count} photos",
    "Approvals",
    "Delete {count} drafts?",
    "Delete selected ({count})",
    "Draft actions",
    "Drafts ({count})",
    "Last saved {count}d ago",
    "Last saved {count}h ago",
    "Last saved {count}m ago",
    "Mentions",
    "New approvals, mentions and comments will appear here.",
    "No saved drafts yet",
    "Notification settings",
    "Notifications are unavailable",
    "Now",
    "Reward added to your AI balance",
    "Save unfinished posts and continue them here later.",
    "Saved just now",
    "Select",
    "This removes only the selected private drafts.",
    "You are all caught up",
    "Earlier",
    "Your account changed. Return to Community to continue.",
    "Keep the text within 1200 characters. Your text is kept.",
    "The action could not be validated. Ask Coach to prepare it again.",
    "This day is closed. Reopen it in Daily Log before making changes.",
    "This meal changed since the action was prepared. Review it again.",
    "The account changed. Reopen AI Coach and try again.",
    "This action was already undone. Nothing was added again.",
    "Undo could not be completed. Review your current data.",
    "Calorie-only entry saved. Other nutrients are unknown.",
    "The change was saved, but its receipt could not be loaded. Retry to read the saved result.",
    "Macro entry saved. Calories are unknown.",
    "This record changed since the action was prepared. Review it again.",
    "Your account changed. Prepare this action again for the current account.",
    "The action was saved, but its current state could not be verified. Review your data before retrying.",
    "Nutrition evidence is incomplete",
    "One or more recorded foods have missing nutrient values.",
    "Review missing food values before interpreting nutrition gaps.",
    "No trusted action is available yet",
    "BIL withheld the recommendation because its deterministic inputs were incomplete or invalid.",
    "Add calories only",
  ];
  static const sources = <String>[..._primarySources, ...supplementalSources];
  static const _supplemental = <String, List<String>>{
    ..._nextWorkspaceSupplementalRows0,
    ..._nextWorkspaceSupplementalRows1,
  };
  static const rows = <String, List<String>>{
    ..._nextWorkspaceRows0,
    ..._nextWorkspaceRows1,
    ..._nextWorkspaceRows2,
    ..._nextWorkspaceRows3,
  };
  static String? resolve(String source, String localeTag) {
    final index = sources.indexOf(source);
    if (index < 0) return null;
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag);
    if (tag == 'en') return source;
    final primary = rows[tag];
    final supplemental = _supplemental[tag];
    if (primary == null || supplemental == null) return null;
    final row = <String>[...primary, ...supplemental];
    if (row.length != sources.length) {
      throw StateError('Incomplete next workspace copy for $tag');
    }
    return row[index];
  }
}
