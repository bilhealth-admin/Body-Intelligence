import 'dart:convert';
import 'settings_store.dart';
import '../localization/bil_locale_policy.dart';
import '../localization/bil_locale_rollout_manifest.dart';

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
    final storedLocale = BilLocalePolicy.canonicalSupportedTag(
      json['localeCode']?.toString(),
    );
    final storedTheme = json['themeMode']?.toString();
    return AppSettings(
      localeCode: storedLocale != null &&
              AppSettingsService.supportedLocaleCodes.contains(storedLocale)
          ? storedLocale
          : AppSettingsService.systemLocaleCode(),
      // Legacy "system" followed the OS and made pages change appearance
      // without an explicit in-app choice. Migrate it to the stable day theme.
      themeMode: storedTheme == 'dark' ? 'dark' : 'light',
      highContrast: json['highContrast'] == true,
      reduceMotion: json['reduceMotion'] == true,
    );
  }
}

class AppSettingsService {
  AppSettingsService({SettingsStore? store})
    : _store = store ?? createSettingsStore();

  final SettingsStore _store;

  static const supportedLocaleCodes = BilLocaleRolloutManifest.releaseTargets25;

  static String systemLocaleCode() {
    // English is the product default for a fresh installation. A locale that
    // the user explicitly selects is persisted and still wins on later runs.
    return 'en';
  }

  Future<AppSettings> load() async {
    try {
      final contents = await _store.read();
      if (contents == null) {
        return AppSettings(localeCode: systemLocaleCode(), themeMode: 'light');
      }
      final decoded = jsonDecode(contents) as Map<String, dynamic>;
      return AppSettings.fromJson(decoded);
    } catch (_) {
      return AppSettings(localeCode: systemLocaleCode(), themeMode: 'light');
    }
  }

  Future<void> save(AppSettings settings) async {
    await _store.write(jsonEncode(settings.toJson()));
  }
}
