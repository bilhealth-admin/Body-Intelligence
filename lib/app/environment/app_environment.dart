class AppEnvironment {
  const AppEnvironment._();

  static const bool useSupabase = bool.fromEnvironment(
    'BIL_USE_SUPABASE',
    defaultValue: false,
  );
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const String serverUrl = String.fromEnvironment('BIL_SERVER_URL');
  static const bool paymentsEnabled = bool.fromEnvironment(
    'BIL_PAYMENTS_ENABLED',
    defaultValue: false,
  );

  static bool get cloudConfigured =>
      useSupabase && supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get serverConfigured => serverUrl.startsWith('https://');
  static bool get aiConfigured => serverConfigured;
  static bool get commerceConfigured => serverConfigured && paymentsEnabled;
}
