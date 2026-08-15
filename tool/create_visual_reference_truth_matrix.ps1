param([string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)

$ErrorActionPreference = 'Stop'
$source = Join-Path $ProjectRoot 'artifacts\release\visual_closure\reference\visual_reference_coverage.csv'
$output = Join-Path $ProjectRoot 'artifacts\release\visual_closure\reference\visual_reference_truth_matrix.csv'
$approvalPath = Join-Path $ProjectRoot 'artifacts\release\visual_closure\reference\visual_reference_independent_approvals.csv'
$approved = @{}
if (Test-Path -LiteralPath $approvalPath) {
  foreach ($approval in Import-Csv -LiteralPath $approvalPath) {
    if (-not $approval.reference -or -not $approval.reviewer -or -not $approval.evidence) {
      throw "Malformed independent visual approval row"
    }
    if ($approved.ContainsKey($approval.reference)) {
      throw "Duplicate independent visual approval for $($approval.reference)"
    }
    $approved[$approval.reference] = $approval
  }
}

function V([string]$name) { "test/visual_closure/goldens/visual_closure_$name.png" }
function G([string]$name) { "test/goldens/$name.png" }

$evidence = @{
  'dashboard' = 1..7 | ForEach-Object { V $(if ($_ -eq 1) { 'dashboard_phone' } else { "dashboard_phone_$_" }) }
  'sleep' = @((V 'sleep_learn_phone'), (V 'sleep_learn_phone_2'), (V 'sleep_learn_phone_3'), (V 'sleep_trend_phone'))
  'food search' = @((V 'food_meal_search_phone'))
  'recipe discovery' = @(
    (V 'recipe_discovery_phone'), (V 'recipe_discovery_phone_2'), (V 'recipe_discovery_phone_3'), (V 'recipe_discovery_phone_4'),
    (V 'recipe_discovery_phone_5'), (V 'recipe_discovery_phone_6'), (V 'recipe_discovery_phone_7'), (V 'recipe_discovery_phone_8'),
    (V 'recipe_discovery_phone_9'), (V 'recipe_discovery_phone_10'), (V 'recipe_discovery_phone_11'), (V 'recipe_discovery_phone_12'),
    (V 'recipe_discovery_phone_13'), (V 'recipe_collection_plant_phone'), (V 'recipe_collection_quick_phone'), (V 'recipe_collection_regional_phone'))
  'recipe collection' = @((V 'recipe_collection_saved_phone'))
  'subscription' = @((V 'store_plans_phone'), (V 'store_plans_phone_2'))
  'workout discovery' = @((V 'workout_library_phone'), (V 'workout_log_phone'), (V 'workout_log_phone_2'), (V 'workout_log_phone_3'), (V 'workout_log_phone_4'), (V 'workout_my_exercises_phone'), (V 'workout_entry_core_phone'))
  'workout routines' = @((V 'workout_routines_saved_phone'), (V 'workout_routine_builder_phone'))
  'apps and devices' = @((V 'connected_health_permission_phone'), (V 'connected_health_compatibility_phone'), (V 'connected_health_unavailable_phone'), (V 'connected_health_update_required_phone'), (V 'connected_health_offline_phone'))
  'friends' = @((V 'community_signed_out_phone'), (V 'community_connections_phone'), (V 'community_profile_phone'), (V 'community_messages_phone'), (V 'community_signed_out_phone'))
  'community profile' = @((V 'community_profile_phone'), (V 'community_connections_phone'), (V 'community_signed_out_phone'))
  'profile' = @((V 'profile_summary_phone'), (V 'profile_phone'))
  'goals' = @((V 'profile_goals_phone'), (V 'dashboard_phone'), (V 'dashboard_preferences_calories_phone'))
  'dashboard customization' = @(
    (V 'dashboard_preferences_phone'), (V 'dashboard_preferences_phone_2'), (V 'dashboard_preferences_calories_phone'), (V 'dashboard_preferences_macros_phone'),
    (V 'dashboard_preferences_activity_phone'), (V 'dashboard_preferences_quick_log_phone'), (V 'dashboard_preferences_discover_phone'), (V 'dashboard_preferences_best_action_phone'),
    (V 'dashboard_preferences_daily_intelligence_phone'), (V 'dashboard_preferences_progress_phone'), (V 'dashboard_preferences_connected_health_phone'), (V 'dashboard_preferences_body_twin_phone'))
  'quick add' = @('test/visual_closure/goldens/quick_add_en_light_phone.png')
  'water entry' = @((V 'daily_log_water_entry_phone'))
  'weight entry' = @((V 'daily_check_in_phone'))
  'exercise entry' = @('walk','run','cycle','swim','strength','upper','lower','core','circuit','row','stairs','hike','dance','yoga','pilates','mobility','stretch','breathing' | ForEach-Object { V "workout_entry_${_}_phone" })
  'meal scan education' = @((V 'meal_image_guide_1_phone'), (V 'meal_image_guide_2_phone'), (V 'meal_image_guide_3_phone'))
  'barcode scan' = @((V 'barcode_unavailable_phone'))
  'food logging' = @((V 'daily_log_meal_entry_phone'), (V 'meal_image_guide_4_phone'))
  'saved food content' = @((V 'food_catalog_verified_result_phone'), (V 'food_catalog_favorite_result_phone'), (V 'food_catalog_recent_result_phone'), (V 'food_catalog_favorites_phone'), (V 'food_catalog_recent_phone'), (G 'epic15_android_phone_en_025_food_search'))
  'custom food' = @((V 'custom_food_phone'), (V 'food_catalog_phone'))
  'diary' = @((V 'daily_log_empty_phone'), (V 'daily_log_meal_entry_phone'), (V 'daily_log_water_entry_phone'))
  'dashboard goals' = @((V 'dashboard_phone'))
  'progress' = @((V 'analytics_progress_phone'), (V 'analytics_seven_days_phone'), (V 'analytics_all_time_phone'), (V 'analytics_empty_phone'))
  'more' = @((V 'settings_phone'), (V 'settings_phone_2'))
  'measurement progress' = @((V 'analytics_progress_phone'))
  'fasting' = @((V 'fasting_phone'))
  'weekly report' = @((G 'epic8_weekly_report_phone_ltr_light'), (G 'epic8_weekly_report_phone_rtl_dark'), (G 'epic8_weekly_report_evidence_phone'), (G 'epic8_weekly_report_empty_phone'), (G 'epic8_weekly_report_nutrition_phone'), (G 'epic8_weekly_report_coverage_phone'), (G 'epic8_weekly_report_sources_phone'))
  'nutrition analytics' = @((V 'analytics_progress_phone'), (V 'analytics_seven_days_phone'), (V 'analytics_all_time_phone'))
  'export' = @((V 'settings_phone_8'))
  'reminders' = @((V 'notification_settings_phone'))
  'community' = @((V 'community_signed_out_phone'), (V 'community_profile_phone'), (V 'community_connections_phone'))
  'community navigation' = @((V 'community_signed_out_phone'), (V 'community_connections_phone'))
  'learn' = @((V 'wellness_learn_phone'), (V 'wellness_learn_nutrition_phone'), (V 'wellness_learn_sleep_phone'), (V 'wellness_learn_movement_phone'), (V 'wellness_learn_privacy_phone'), (V 'wellness_learn_article_nutrition_phone'), (V 'wellness_learn_article_sleep_phone'), (V 'wellness_learn_article_movement_phone'), (V 'wellness_learn_article_privacy_phone'), (V 'wellness_learn_phone_2'), (V 'wellness_learn_phone_3'), (V 'wellness_learn_phone_4'))
  'messages' = @((V 'community_messages_phone'), (V 'community_signed_out_phone'))
  'settings' = 1..9 | ForEach-Object { V $(if ($_ -eq 1) { 'settings_phone' } else { "settings_phone_$_" }) }
  'legal' = @((V 'privacy_policy_phone'), (V 'terms_phone'))
  'privacy consent' = @((V 'advertising_privacy_phone'))
  'privacy and health access' = @(
    (V 'connected_health_permission_phone'), (V 'connected_health_compatibility_phone'), (V 'connected_health_unavailable_phone'),
    (V 'connected_health_update_required_phone'), (V 'connected_health_offline_phone'),
    (G 'epic15_iphone_69_en_06_privacy_settings'), (G 'epic15_android_phone_en_05_connected_health'),
    (G 'epic15_iphone_69_ar_06_connected_health'), (G 'epic15_iphone_69_en_05_connected_health'),
    (G 'epic15_iphone_69_ar_08_privacy_settings_dark'), (G 'epic15_android_phone_ar_06_connected_health'))
  'help' = @((V 'help_center_phone'), (V 'help_faq_targets_phone'), (V 'help_faq_offline_phone'), (V 'help_faq_medical_phone'), (V 'help_troubleshooting_phone'), (V 'help_service_status_phone'))
}

$external = @{
  'subscription' = 'store_products_and_sandbox_purchase_external_required'
  'apps and devices' = 'physical_health_source_and_ble_device_external_required'
  'friends' = 'credentialled_two_account_cloud_validation_external_required'
  'community profile' = 'credentialled_cloud_profile_validation_external_required'
  'barcode scan' = 'physical_camera_and_real_barcode_external_required'
  'community' = 'credentialled_cloud_content_validation_external_required'
  'community navigation' = 'credentialled_cloud_navigation_validation_external_required'
  'messages' = 'credentialled_two_account_realtime_validation_external_required'
  'privacy and health access' = 'physical_os_permission_sheets_external_required'
}

$positions = @{}
$rows = foreach ($row in Import-Csv -LiteralPath $source) {
  $screen = $row.screen
  if (-not $evidence.ContainsKey($screen)) { throw "No truthful evidence mapping for $screen ($($row.reference))" }
  $index = if ($positions.ContainsKey($screen)) { $positions[$screen] } else { 0 }
  $choices = @($evidence[$screen])
  if ($index -ge $choices.Count) { throw "Insufficient distinct evidence for $screen ($($row.reference))" }
  $relative = $choices[$index]
  $positions[$screen] = $index + 1
  $absolute = Join-Path $ProjectRoot ($relative -replace '/', '\')
  if (-not (Test-Path -LiteralPath $absolute)) { throw "Missing evidence $relative for $($row.reference)" }
  $blocker = if ($external.ContainsKey($screen)) { $external[$screen] } else { '' }
  $isApproved = $approved.ContainsKey($row.reference)
  if ($isApproved -and $blocker) {
    throw "Reference $($row.reference) cannot be approved while externally blocked"
  }
  [pscustomobject]@{
    reference = $row.reference
    source_image = $row.name
    screen = $screen
    route = $row.bil_route
    production_file = $row.production_file
    evidence_after = $relative
    evidence_bytes = (Get-Item -LiteralPath $absolute).Length
    # A rendered production image proves only that the route/state can be
    # captured. It is not evidence of visual equivalence with the reference.
    implementation_status = if ($blocker) { 'production_state_captured_external_validation_pending' } elseif ($isApproved) { 'production_state_captured_independently_reviewed' } else { 'production_state_captured_visual_equivalence_unverified' }
    external_blocker = $blocker
    visual_review_status = if ($isApproved) { 'approved_visual_equivalence' } else { 'unmatched_until_human_or_pixel_review_passes' }
  }
}

$matrixReferences = @($rows | ForEach-Object { $_.reference })
foreach ($reference in $approved.Keys) {
  if ($matrixReferences -notcontains $reference) {
    throw "Independent approval references unknown visual row $reference"
  }
}

$rows | Export-Csv -LiteralPath $output -NoTypeInformation -Encoding utf8
Write-Output "TRUTH_MATRIX_ROWS=$($rows.Count)"
Write-Output "EXTERNAL_VALIDATION_ROWS=$(@($rows | Where-Object external_blocker).Count)"
Write-Output "MATRIX=$output"
