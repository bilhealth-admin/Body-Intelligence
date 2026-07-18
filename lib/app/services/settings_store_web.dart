import 'package:shared_preferences/shared_preferences.dart';

import 'settings_store.dart';

SettingsStore createPlatformSettingsStore() => _WebSettingsStore();

class _WebSettingsStore implements SettingsStore {
  static const key = 'bil_app_settings';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String value) async {
    await (await SharedPreferences.getInstance()).setString(key, value);
  }
}
