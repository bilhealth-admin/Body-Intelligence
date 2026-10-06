import 'bil_locale_policy.dart';

part 'runtime_copy_next_workspace_0.dart';
part 'runtime_copy_next_workspace_1.dart';
part 'runtime_copy_next_workspace_2.dart';
part 'runtime_copy_next_workspace_3.dart';

/// Authored next-version workspace and inbox copy; all locale rows are tested.
abstract final class NextWorkspaceRuntimeCopy {
  static const sources = <String>[
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
    final row = rows[tag];
    if (row == null) return null;
    if (row.length != sources.length) {
      throw StateError('Incomplete next workspace copy for $tag');
    }
    return row[index];
  }
}
