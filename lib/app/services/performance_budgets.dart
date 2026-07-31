class PerformanceBudgets {
  const PerformanceBudgets._();

  /// Local database connection plus fresh-schema initialization on test host.
  static const databaseStartup = Duration(seconds: 2);

  /// Search across a representative 1,000-row local catalog.
  static const foodSearch = Duration(milliseconds: 500);
}
