/// Classifies loading failures without leaking storage details or identifiers.
///
/// Stage separation matters: reading the local plan is independent from
/// validating its supporting catalog and dietary preferences.
String classifySmartPlanLoadFailure(
  Object error, {
  required bool duringCatalog,
}) {
  final description = error.toString();
  if (description.contains('smart_plan_foreign_owner')) {
    return 'smart_plan_owner_mismatch';
  }
  if (description.contains('smart_plan_owner_changed')) {
    return 'smart_plan_owner_changed';
  }
  if (description.contains('smart_plan_revision_conflict')) {
    return 'smart_plan_revision_conflict';
  }
  if (duringCatalog) {
    return 'smart_plan_catalog_unavailable';
  }
  if (error is FormatException) {
    return 'smart_plan_saved_data_invalid';
  }
  return 'smart_plan_storage_unavailable';
}
