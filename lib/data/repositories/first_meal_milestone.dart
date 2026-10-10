/// Per-owner local database preference written with a REAL food item.
///
/// 'ready' is displayed at most once after an atomic first commit;
/// 'done' means already celebrated or legacy food records were detected.
/// Never use this flag to infer a meal, credit, subscription, or user identity.
const firstMealCelebrationPreferenceKey = 'experience.first_food_commit.v1';

/// Optional follow-up pointing to daily streaks after the first real save.
const firstMealStreakGuidePreferenceKey = 'experience.first_food_streak.v1';
