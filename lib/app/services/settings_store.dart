import 'settings_store_unsupported.dart'
    if (dart.library.ffi) 'settings_store_native.dart'
    if (dart.library.js_interop) 'settings_store_web.dart';

abstract interface class SettingsStore {
  Future<String?> read();
  Future<void> write(String value);
}

SettingsStore createSettingsStore() => createPlatformSettingsStore();
