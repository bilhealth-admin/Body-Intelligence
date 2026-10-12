import 'dart:io';

import 'health_storage_directory_native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_store.dart';
import 'health_storage_privacy.dart';

SettingsStore createPlatformSettingsStore() => _NativeSettingsStore();

class _NativeSettingsStore implements SettingsStore {
  static const key = 'bil_app_settings';

  @override
  Future<String?> read() async {
    await BilHealthStoragePrivacy.instance.ensureProtected();
    final preferences = await SharedPreferences.getInstance();
    final current = preferences.getString(key);
    if (current != null) return current;
    final directory = await getProtectedApplicationSupportDirectory();
    final legacy = File('${directory.path}/app_settings.json');
    if (!await legacy.exists()) return null;
    final value = await legacy.readAsString();
    final migrated = await preferences.setString(key, value);
    if (!migrated) {
      throw StateError('Legacy settings migration was not persisted.');
    }
    return value;
  }

  @override
  Future<void> write(String value) async {
    await BilHealthStoragePrivacy.instance.ensureProtected();
    final persisted = await (await SharedPreferences.getInstance()).setString(
      key,
      value,
    );
    if (!persisted) {
      throw StateError('App settings were not persisted.');
    }
  }
}
