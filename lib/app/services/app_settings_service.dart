import 'dart:convert';

import 'settings_store.dart';

class AppSettings {
  AppSettings({
    required this.localeCode,
    required this.themeMode,
    this.highContrast = false,
    this.reduceMotion = false,
  });

  final String localeCode;
  final String themeMode;
  final bool highContrast;
  final bool reduceMotion;

  AppSettings copyWith({
    String? localeCode,
    String? themeMode,
    bool? highContrast,
    bool? reduceMotion,
  }) => AppSettings(
    localeCode: localeCode ?? this.localeCode,
    themeMode: themeMode ?? this.themeMode,
    highContrast: highContrast ?? this.highContrast,
    reduceMotion: reduceMotion ?? this.reduceMotion,
  );

  Map<String, dynamic> toJson() => {
    'localeCode': localeCode,
    'themeMode': themeMode,
    'highContrast': highContrast,
    'reduceMotion': reduceMotion,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      localeCode: json['localeCode']?.toString() ?? 'en',
      themeMode: json['themeMode']?.toString() ?? 'system',
      highContrast: json['highContrast'] == true,
      reduceMotion: json['reduceMotion'] == true,
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
