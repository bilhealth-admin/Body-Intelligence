import 'dart:convert';

import 'settings_store.dart';

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
      localeCode: json['localeCode']?.toString() ?? 'en',
      themeMode: json['themeMode']?.toString() ?? 'system',
    );
  }
}

class AppSettingsService {
  AppSettingsService({SettingsStore? store})
    : _store = store ?? createSettingsStore();

  final SettingsStore _store;

  Future<AppSettings> load() async {
    try {
      final contents = await _store.read();
      if (contents == null) {
        return AppSettings(localeCode: 'en', themeMode: 'system');
      }
      final decoded = jsonDecode(contents) as Map<String, dynamic>;
      return AppSettings.fromJson(decoded);
    } catch (_) {
      return AppSettings(localeCode: 'en', themeMode: 'system');
    }
  }

  Future<void> save(AppSettings settings) async {
    await _store.write(jsonEncode(settings.toJson()));
  }
}
