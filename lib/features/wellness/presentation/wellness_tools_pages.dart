import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/database/app_database.dart';
import '../../daily_log/providers/daily_log_provider.dart';
import '../../life_context/providers/life_context_provider.dart';
import '../../notifications/services/bil_notification_service.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../domain/fasting_session.dart';
import 'wellness_copy.dart';

part 'sleep_tracker_page.dart';
part 'sleep_tracker_experience.dart';
part 'workout_library_page.dart';
part 'fasting_timer_page.dart';
part 'wellness_tool_components.dart';

final fastingNotificationServiceProvider = Provider<BilNotificationService>(
  (_) => BilNotificationService(FlutterLocalNotificationsPlugin()),
);

mixin _WellnessCopy<T extends StatefulWidget> on State<T> {
  bool get ar => Localizations.localeOf(context).languageCode == 'ar';
  String tr(String en, String arText) => wellnessCopy(context, en, arText);
}
