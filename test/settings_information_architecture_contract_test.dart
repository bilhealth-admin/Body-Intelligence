import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('More and Settings remain separate reference hierarchies', () {
    final more = File(
      'lib/features/settings/settings_page.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/settings/reference_settings_home_page.dart',
    ).readAsStringSync();

    var previous = -1;
    for (final label in const [
      'Try Premium for Free',
      'My Profile',
      'Intermittent Fasting',
      'Sleep',
      'Recipe Discovery',
      'Workout Routines',
      'Goals',
      'Progress',
      'Weekly Report',
      'Nutrition',
      'My Meals, Recipes & Foods',
      'Reminders',
      'Apps & Devices',
      'Steps',
      'Community',
      'Learn',
      'Friends',
      'Messages',
      'Settings',
      'Privacy',
      'Help',
      'Sync',
    ]) {
      final index = more.indexOf("copy('$label')");
      expect(index, greaterThan(previous), reason: label);
      previous = index;
    }

    previous = -1;
    for (final label in const [
      'Profile',
      'App Appearance',
      'Diary Settings',
      'Sharing & Privacy',
      'My Exercises',
      'Weekly Nutrition Settings',
      'Push Notifications',
      'Logout',
    ]) {
      final index = settings.indexOf("copy('$label')");
      expect(index, greaterThan(previous), reason: label);
      previous = index;
    }
    expect(more, contains("'/settings/preferences'"));
    expect(settings, isNot(contains('Today dashboard')));
  });

  test('reference destinations remain functional routes', () {
    final more = File(
      'lib/features/settings/settings_page.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/settings/reference_settings_home_page.dart',
    ).readAsStringSync();
    final combined = '$more\n$settings';
    for (final route in const [
      '/plans',
      '/profile-settings',
      '/wellness/fasting',
      '/wellness/sleep',
      '/wellness/recipes',
      '/wellness/workouts/routines',
      '/history',
      '/weekly-report',
      '/challenges',
      '/nutrition',
      '/notification-settings',
      '/connected-health',
      '/community',
      '/wellness/learn',
      '/community/people',
      '/settings/preferences',
      '/help',
      '/settings/appearance',
      '/settings/diary',
      '/settings/sharing-privacy',
      '/wellness/workouts/log',
      '/settings/nutrition-goals',
    ]) {
      expect(combined, contains("'$route'"), reason: route);
    }
  });
}
