class AppEnvironment {
  const AppEnvironment._();

  static const bool useSupabase = false;
  static const String supabaseUrl = '';
  static const String supabaseAnonKey = '';

  static bool get cloudConfigured =>
      useSupabase && supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
