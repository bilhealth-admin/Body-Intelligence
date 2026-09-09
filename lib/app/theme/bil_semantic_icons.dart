import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Stable functional meanings used by entry points throughout BIL.
///
/// A semantic color supports the accompanying glyph and text. It must never be
/// the only way an action or health category is identified.
enum BilSemanticIconKind {
  foodLog,
  foodSearch,
  meal,
  barcode,
  voice,
  mealPhoto,
  notes,
  water,
  weight,
  exercise,
  breakfast,
  lunch,
  dinner,
  snack,
  profile,
  appearance,
  language,
  location,
  goals,
  progress,
  report,
  challenges,
  nutrition,
  recipes,
  fasting,
  sleep,
  devices,
  steps,
  learn,
  community,
  friends,
  messages,
  privacy,
  notifications,
  preferences,
  support,
  aiCoach,
  cloudSync,
  moderation,
  verifiedFood,
  measurements,
  calendar,
  time,
  export,
  accountDeletion,
  legal,
  health,
  heartRate,
  distance,
  bodyFat,
  oxygen,
  synchronization,
}

@immutable
class BilSemanticIconSpec {
  const BilSemanticIconSpec({
    required this.icon,
    required this.appleIcon,
    required this.lightAccent,
    required this.darkAccent,
    required this.lightContainer,
    required this.darkContainer,
  });

  final IconData icon;
  final IconData appleIcon;
  final Color lightAccent;
  final Color darkAccent;
  final Color lightContainer;
  final Color darkContainer;

  Color accent(Brightness brightness) =>
      brightness == Brightness.dark ? darkAccent : lightAccent;

  Color container(Brightness brightness) =>
      brightness == Brightness.dark ? darkContainer : lightContainer;

  /// Foreground used when [accent] itself is the solid badge surface.
  Color onAccent(Brightness brightness) =>
      brightness == Brightness.dark ? darkContainer : Colors.white;

  /// Resolves a native-looking glyph without changing the functional meaning.
  IconData iconFor(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => appleIcon,
    _ => icon,
  };
}

/// One modern, rounded icon vocabulary shared by BIL entry points.
abstract final class BilSemanticIcons {
  static const today = Icons.dashboard_outlined;
  static const todaySelected = Icons.dashboard_rounded;
  static const diary = Icons.menu_book_outlined;
  static const diarySelected = Icons.menu_book_rounded;
  static const discover = Icons.explore_outlined;
  static const discoverSelected = Icons.explore_rounded;
  static const progress = Icons.trending_up_rounded;
  static const progressSelected = Icons.insights_rounded;
  static const insights = Icons.auto_awesome_outlined;
  static const insightsSelected = Icons.auto_awesome_rounded;
  // Keep "More" visually distinct from the dashboard grid used by Today.
  static const more = Icons.more_horiz_rounded;
  static const moreSelected = Icons.more_horiz_rounded;
  static const water = Icons.water_drop_outlined;
  static const weight = Icons.monitor_weight_outlined;
  static const meal = Icons.restaurant_rounded;
  static const workout = Icons.fitness_center_rounded;
  static const subscription = Icons.workspace_premium_outlined;
  static const deleteAccount = Icons.person_remove_outlined;
  static const action = Icons.arrow_forward_rounded;

  static const _blue = BilSemanticIconSpec(
    icon: Icons.search_rounded,
    appleIcon: CupertinoIcons.search,
    lightAccent: Color(0xFF075BBB),
    darkAccent: Color(0xFF89C0FF),
    lightContainer: Color(0xFFE7F1FF),
    darkContainer: Color(0xFF17375F),
  );
  static const _rose = BilSemanticIconSpec(
    // Food packaging uses linear barcodes. A QR matrix or handheld scanner
    // glyph misrepresents this action; the bundled viewfinder works on both.
    icon: CupertinoIcons.barcode_viewfinder,
    appleIcon: CupertinoIcons.barcode_viewfinder,
    lightAccent: Color(0xFFB51650),
    darkAccent: Color(0xFFFF9AB9),
    lightContainer: Color(0xFFFFE8F0),
    darkContainer: Color(0xFF57182E),
  );
  static const _purple = BilSemanticIconSpec(
    icon: Icons.mic_rounded,
    appleIcon: CupertinoIcons.mic,
    lightAccent: Color(0xFF64118A),
    darkAccent: Color(0xFFDFA0FF),
    lightContainer: Color(0xFFF7E8FF),
    darkContainer: Color(0xFF421354),
  );
  static const _teal = BilSemanticIconSpec(
    icon: Icons.center_focus_strong_rounded,
    appleIcon: CupertinoIcons.camera_viewfinder,
    lightAccent: Color(0xFF006A63),
    darkAccent: Color(0xFF70E0D4),
    lightContainer: Color(0xFFDDF8F4),
    darkContainer: Color(0xFF113F3C),
  );
  static const _azure = BilSemanticIconSpec(
    icon: Icons.water_drop_rounded,
    appleIcon: CupertinoIcons.drop,
    lightAccent: Color(0xFF006493),
    darkAccent: Color(0xFF7DD0FF),
    lightContainer: Color(0xFFE1F4FF),
    darkContainer: Color(0xFF123C54),
  );
  static const _emerald = BilSemanticIconSpec(
    icon: Icons.monitor_weight_outlined,
    // Cupertino has no unambiguous body-scale glyph. Keep the accurate
    // neutral Material symbol instead of presenting a speedometer gauge.
    appleIcon: Icons.monitor_weight_outlined,
    lightAccent: Color(0xFF08724F),
    darkAccent: Color(0xFF6ADCB0),
    lightContainer: Color(0xFFE2F7EE),
    darkContainer: Color(0xFF133F32),
  );
  static const _amber = BilSemanticIconSpec(
    icon: Icons.fitness_center_rounded,
    appleIcon: CupertinoIcons.flame,
    lightAccent: Color(0xFF914600),
    darkAccent: Color(0xFFFFBD78),
    lightContainer: Color(0xFFFFF0DC),
    darkContainer: Color(0xFF51300F),
  );
  static const _indigo = BilSemanticIconSpec(
    icon: Icons.bedtime_outlined,
    appleIcon: CupertinoIcons.bed_double,
    lightAccent: Color(0xFF3B3D9C),
    darkAccent: Color(0xFFB0B2FF),
    lightContainer: Color(0xFFECECFF),
    darkContainer: Color(0xFF2C2D62),
  );
  static const _cyan = BilSemanticIconSpec(
    icon: Icons.auto_awesome_rounded,
    appleIcon: CupertinoIcons.sparkles,
    lightAccent: Color(0xFF00677A),
    darkAccent: Color(0xFF71E4F6),
    lightContainer: Color(0xFFDDF7FC),
    darkContainer: Color(0xFF123F49),
  );
  static const _green = BilSemanticIconSpec(
    icon: Icons.shield_outlined,
    appleIcon: CupertinoIcons.shield,
    lightAccent: Color(0xFF176B38),
    darkAccent: Color(0xFF7DDA9E),
    lightContainer: Color(0xFFE5F6EA),
    darkContainer: Color(0xFF183D27),
  );
  static const _slate = BilSemanticIconSpec(
    icon: Icons.person_outline_rounded,
    appleIcon: CupertinoIcons.person_crop_circle,
    lightAccent: Color(0xFF40566F),
    darkAccent: Color(0xFFB7C9DB),
    lightContainer: Color(0xFFEAF0F6),
    darkContainer: Color(0xFF293848),
  );
  static const _berry = BilSemanticIconSpec(
    icon: Icons.favorite_outline_rounded,
    appleIcon: CupertinoIcons.heart,
    lightAccent: Color(0xFF9B2949),
    darkAccent: Color(0xFFFF9BB7),
    lightContainer: Color(0xFFFFE9EF),
    darkContainer: Color(0xFF502133),
  );

  static BilSemanticIconSpec spec(BilSemanticIconKind kind) => switch (kind) {
    BilSemanticIconKind.foodLog => _blue,
    BilSemanticIconKind.foodSearch => _copy(
      _cyan,
      Icons.manage_search_rounded,
      CupertinoIcons.search,
    ),
    BilSemanticIconKind.meal => _copy(
      _amber,
      Icons.restaurant_rounded,
      Icons.restaurant_rounded,
    ),
    BilSemanticIconKind.barcode => _rose,
    BilSemanticIconKind.voice => _purple,
    BilSemanticIconKind.mealPhoto => _teal,
    BilSemanticIconKind.notes => _copy(
      _indigo,
      Icons.edit_note_rounded,
      CupertinoIcons.square_pencil,
    ),
    BilSemanticIconKind.water => _azure,
    BilSemanticIconKind.weight => _emerald,
    BilSemanticIconKind.exercise => _amber,
    BilSemanticIconKind.breakfast => _copy(
      _amber,
      Icons.wb_sunny_outlined,
      CupertinoIcons.sunrise,
    ),
    BilSemanticIconKind.lunch => _copy(
      _teal,
      Icons.restaurant_outlined,
      Icons.restaurant_outlined,
    ),
    BilSemanticIconKind.dinner => _copy(
      _indigo,
      Icons.nights_stay_outlined,
      Icons.restaurant_outlined,
    ),
    BilSemanticIconKind.snack => _copy(
      _rose,
      Icons.cookie_outlined,
      Icons.cookie_outlined,
    ),
    BilSemanticIconKind.profile => _slate,
    BilSemanticIconKind.appearance => _copy(
      _purple,
      Icons.palette_outlined,
      CupertinoIcons.paintbrush,
    ),
    BilSemanticIconKind.language => _copy(
      _blue,
      Icons.language_rounded,
      CupertinoIcons.globe,
    ),
    BilSemanticIconKind.location => _copy(
      _amber,
      Icons.location_on_outlined,
      CupertinoIcons.location,
    ),
    BilSemanticIconKind.goals => _copy(
      _purple,
      Icons.track_changes_rounded,
      CupertinoIcons.scope,
    ),
    BilSemanticIconKind.progress => _copy(
      _purple,
      Icons.insights_rounded,
      CupertinoIcons.chart_bar,
    ),
    BilSemanticIconKind.report => _copy(
      _teal,
      Icons.assessment_outlined,
      CupertinoIcons.doc_chart,
    ),
    BilSemanticIconKind.challenges => _copy(
      _amber,
      Icons.emoji_events_outlined,
      CupertinoIcons.rosette,
    ),
    BilSemanticIconKind.nutrition => _copy(
      _green,
      Icons.pie_chart_outline_rounded,
      CupertinoIcons.chart_pie,
    ),
    BilSemanticIconKind.recipes => _copy(
      _amber,
      Icons.restaurant_menu_rounded,
      CupertinoIcons.book,
    ),
    BilSemanticIconKind.fasting => _copy(
      _purple,
      Icons.hourglass_bottom_rounded,
      CupertinoIcons.timer,
    ),
    BilSemanticIconKind.sleep => _indigo,
    BilSemanticIconKind.devices => _copy(
      _cyan,
      Icons.watch_outlined,
      CupertinoIcons.device_phone_portrait,
    ),
    BilSemanticIconKind.steps => _copy(
      _green,
      Icons.directions_walk_rounded,
      Icons.directions_walk_rounded,
    ),
    BilSemanticIconKind.learn => _copy(
      _blue,
      Icons.school_outlined,
      CupertinoIcons.book,
    ),
    BilSemanticIconKind.community => _copy(
      _teal,
      Icons.groups_2_outlined,
      CupertinoIcons.person_2,
    ),
    BilSemanticIconKind.friends => _copy(
      _blue,
      Icons.person_add_alt_rounded,
      CupertinoIcons.person_add,
    ),
    BilSemanticIconKind.messages => _copy(
      _purple,
      Icons.chat_bubble_outline_rounded,
      CupertinoIcons.chat_bubble_2,
    ),
    BilSemanticIconKind.privacy => _green,
    BilSemanticIconKind.notifications => _copy(
      _amber,
      Icons.notifications_none_rounded,
      CupertinoIcons.bell,
    ),
    BilSemanticIconKind.preferences => _copy(
      _slate,
      Icons.settings_outlined,
      CupertinoIcons.slider_horizontal_3,
    ),
    BilSemanticIconKind.support => _copy(
      _blue,
      Icons.support_agent_rounded,
      CupertinoIcons.question_circle,
    ),
    BilSemanticIconKind.aiCoach => _cyan,
    BilSemanticIconKind.cloudSync => _copy(
      _blue,
      Icons.cloud_sync_outlined,
      CupertinoIcons.cloud_upload,
    ),
    BilSemanticIconKind.moderation => _copy(
      _slate,
      Icons.admin_panel_settings_outlined,
      CupertinoIcons.checkmark_shield,
    ),
    BilSemanticIconKind.verifiedFood => _copy(
      _green,
      Icons.fact_check_outlined,
      CupertinoIcons.checkmark_seal,
    ),
    BilSemanticIconKind.measurements => _copy(
      _purple,
      Icons.straighten_rounded,
      Icons.straighten_rounded,
    ),
    BilSemanticIconKind.calendar => _copy(
      _blue,
      Icons.calendar_today_rounded,
      CupertinoIcons.calendar,
    ),
    BilSemanticIconKind.time => _copy(
      _blue,
      Icons.schedule_rounded,
      CupertinoIcons.clock,
    ),
    BilSemanticIconKind.export => _copy(
      _teal,
      Icons.file_download_outlined,
      CupertinoIcons.arrow_down_doc,
    ),
    BilSemanticIconKind.accountDeletion => _copy(
      _rose,
      Icons.person_remove_outlined,
      CupertinoIcons.person_badge_minus,
    ),
    BilSemanticIconKind.legal => _copy(
      _slate,
      Icons.gavel_outlined,
      CupertinoIcons.doc_text,
    ),
    BilSemanticIconKind.health => _berry,
    BilSemanticIconKind.heartRate => _copy(
      _berry,
      Icons.monitor_heart_outlined,
      CupertinoIcons.waveform_path_ecg,
    ),
    BilSemanticIconKind.distance => _copy(
      _teal,
      Icons.route_outlined,
      CupertinoIcons.map,
    ),
    BilSemanticIconKind.bodyFat => _copy(
      _amber,
      Icons.accessibility_new_rounded,
      CupertinoIcons.person,
    ),
    BilSemanticIconKind.oxygen => _copy(
      _azure,
      Icons.air_rounded,
      CupertinoIcons.wind,
    ),
    BilSemanticIconKind.synchronization => _copy(
      _cyan,
      Icons.sync_rounded,
      CupertinoIcons.arrow_2_circlepath,
    ),
  };

  static BilSemanticIconKind? kindForRoute(String route) => switch (Uri.parse(
    route,
  ).path) {
    '/profile-summary' || '/profile-settings' => BilSemanticIconKind.profile,
    '/settings/appearance' => BilSemanticIconKind.appearance,
    '/settings/language' => BilSemanticIconKind.language,
    '/location-settings' => BilSemanticIconKind.location,
    '/goals' || '/settings/nutrition-goals' => BilSemanticIconKind.goals,
    '/settings/diary' => BilSemanticIconKind.notes,
    '/settings/exercise-calories' => BilSemanticIconKind.exercise,
    '/settings/local-export' => BilSemanticIconKind.export,
    '/nutrition-plans' => BilSemanticIconKind.nutrition,
    '/history' || '/weight-history' => BilSemanticIconKind.progress,
    '/weekly-report' => BilSemanticIconKind.report,
    '/challenges' => BilSemanticIconKind.challenges,
    '/analytics/nutrition' => BilSemanticIconKind.nutrition,
    '/nutrition' => BilSemanticIconKind.recipes,
    '/intelligence-center' ||
    '/settings/ai-coach' => BilSemanticIconKind.aiCoach,
    '/wellness/fasting' => BilSemanticIconKind.fasting,
    '/wellness/sleep' => BilSemanticIconKind.sleep,
    '/wellness/recipes' => BilSemanticIconKind.recipes,
    '/wellness/workouts/routines' ||
    '/wellness/workouts/log' => BilSemanticIconKind.exercise,
    '/connected-health' => BilSemanticIconKind.devices,
    '/connected-health/steps' => BilSemanticIconKind.steps,
    '/wellness/learn' || '/wellness-library' => BilSemanticIconKind.learn,
    '/community' => BilSemanticIconKind.community,
    '/community/people' ||
    '/community/connections' => BilSemanticIconKind.friends,
    '/community/messages' => BilSemanticIconKind.messages,
    '/community/moderation' => BilSemanticIconKind.moderation,
    '/community/safety' => BilSemanticIconKind.privacy,
    '/community/profile' => BilSemanticIconKind.profile,
    '/community/food-review' => BilSemanticIconKind.verifiedFood,
    '/notification-settings' => BilSemanticIconKind.notifications,
    '/settings/preferences' => BilSemanticIconKind.preferences,
    '/settings/sharing-privacy' ||
    '/advertising-privacy' => BilSemanticIconKind.privacy,
    '/help' => BilSemanticIconKind.support,
    '/help/delete-account' => BilSemanticIconKind.accountDeletion,
    '/legal/privacy' => BilSemanticIconKind.privacy,
    '/legal/terms' => BilSemanticIconKind.legal,
    '/admin/ai-coach' => BilSemanticIconKind.moderation,
    _ => null,
  };

  static BilSemanticIconKind kindForHealthSignal(String key) {
    final normalized = key.toLowerCase();
    if (normalized.contains('step')) return BilSemanticIconKind.steps;
    if (normalized.contains('distance')) return BilSemanticIconKind.distance;
    if (normalized.contains('sleep')) return BilSemanticIconKind.sleep;
    if (normalized.contains('weight')) return BilSemanticIconKind.weight;
    if (normalized.contains('fat')) return BilSemanticIconKind.bodyFat;
    if (normalized.contains('oxygen') || normalized.contains('spo2')) {
      return BilSemanticIconKind.oxygen;
    }
    if (normalized.contains('heart') || normalized.contains('pulse')) {
      return BilSemanticIconKind.heartRate;
    }
    if (normalized.contains('sync')) {
      return BilSemanticIconKind.synchronization;
    }
    return BilSemanticIconKind.health;
  }

  static BilSemanticIconSpec _copy(
    BilSemanticIconSpec palette,
    IconData icon,
    IconData appleIcon,
  ) => BilSemanticIconSpec(
    icon: icon,
    appleIcon: appleIcon,
    lightAccent: palette.lightAccent,
    darkAccent: palette.darkAccent,
    lightContainer: palette.lightContainer,
    darkContainer: palette.darkContainer,
  );
}

/// Reusable icon treatment for functional entry points.
///
/// Interactive hit targets remain the responsibility of the surrounding tile
/// or button; this widget is presentation-only and excludes duplicate icon
/// semantics while exposing the supplied functional label.
class BilSemanticIconBadge extends StatelessWidget {
  const BilSemanticIconBadge({
    super.key,
    required this.kind,
    this.semanticLabel,
    this.size = 40,
    this.iconSize = 22,
    this.shape = BoxShape.circle,
    this.iconOverride,
    this.appleIconOverride,
    this.platformOverride,
  });

  final BilSemanticIconKind kind;
  final String? semanticLabel;
  final double size;
  final double iconSize;
  final BoxShape shape;
  final IconData? iconOverride;
  final IconData? appleIconOverride;
  final TargetPlatform? platformOverride;

  @override
  Widget build(BuildContext context) {
    final spec = BilSemanticIcons.spec(kind);
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final platform = platformOverride ?? theme.platform;
    final resolvedIcon = switch (platform) {
      TargetPlatform.iOS ||
      TargetPlatform.macOS => appleIconOverride ?? spec.appleIcon,
      _ => iconOverride ?? spec.icon,
    };
    final visual = ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: spec.container(brightness),
          shape: shape,
          borderRadius: shape == BoxShape.rectangle
              ? BorderRadius.circular(size * .3)
              : null,
        ),
        alignment: Alignment.center,
        child: Icon(
          resolvedIcon,
          color: spec.accent(brightness),
          size: iconSize,
        ),
      ),
    );
    final label = semanticLabel?.trim();
    if (label == null || label.isEmpty) return visual;
    return Semantics(label: label, image: true, child: visual);
  }
}
