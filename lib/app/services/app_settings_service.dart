import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AppSettings {
  AppSettings({required this.localeCode, required this.themeMode});

  final String localeCode;
  final String themeMode;

  AppSettings copyWith({String? localeCode, String? themeMode}) => AppSettings(
    localeCode: localeCode ?? this.localeCode,
    themeMode: themeMode ?? this.themeMode,
  );

  Map<String, dynamic> toJson() => {
    'localeCode': localeCode,
    'themeMode': themeMode,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      localeCode: json['localeCode']?.toString() ?? 'ar',
      themeMode: json['themeMode']?.toString() ?? 'system',
    );
  }
}

class AppSettingsService {
  Future<File> _localFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/app_settings.json');
  }

  Future<AppSettings> load() async {
    try {
      final file = await _localFile();
      if (!await file.exists()) {
        return AppSettings(localeCode: 'ar', themeMode: 'system');
      }
      final contents = await file.readAsString();
      final decoded = jsonDecode(contents) as Map<String, dynamic>;
      return AppSettings.fromJson(decoded);
    } catch (_) {
      return AppSettings(localeCode: 'ar', themeMode: 'system');
    }
  }

  Future<void> save(AppSettings settings) async {
    final file = await _localFile();
    await file.writeAsString(jsonEncode(settings.toJson()));
  }
}
