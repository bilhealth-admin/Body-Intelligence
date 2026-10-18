import 'package:flutter_riverpod/legacy.dart';

import '../domain/coach_action_permission.dart';

/// Shared app-session permission mode for Coach write actions. It is exposed
/// from Coach settings, while the admission gate continues to enforce every
/// action independently of where the preference is changed.
final coachActionPermissionModeProvider =
    StateProvider<CoachActionPermissionMode>(
      (ref) => CoachActionPermissionMode.askBeforeWrite,
    );
