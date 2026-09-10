package com.bilhealth.bodyintelligencelog

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.HealthConnectFeatures
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.changes.DeletionChange
import androidx.health.connect.client.changes.UpsertionChange
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import androidx.health.connect.client.request.ChangesTokenRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.request.AggregateGroupByPeriodRequest
import androidx.health.connect.client.aggregate.AggregateMetric
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.Instant
import java.time.ZoneOffset
import java.time.ZoneId
import java.time.Period
import kotlin.reflect.KClass

/** Production Health Connect bridge. Device/OEM certification is tracked separately. */
class BILGlobalHealthBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
    private val permissionLauncher: ActivityResultLauncher<Set<String>>,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var pendingPermissionResult: MethodChannel.Result? = null
    private val client: HealthConnectClient? by lazy {
        if (availability() == HealthConnectClient.SDK_AVAILABLE) HealthConnectClient.getOrCreate(activity) else null
    }

    init { channel.setMethodCallHandler(this) }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "availability" -> result.success(mapOf("available" to (availability() == HealthConnectClient.SDK_AVAILABLE), "status" to availability(), "platform" to "health_connect"))
            "permissions" -> run(result) { permissionSnapshot(call.argument<List<String>>("types") ?: supportedNames) }
            "requestPermissions" -> requestPermissions(call, result)
            "revokeAccess" -> run(result) {
                requireClient().permissionController.revokeAllPermissions()
                mapOf("revoked" to true, "platform" to "health_connect")
            }
            "openSettings" -> {
                val status = availability()
                val intent = if (status == HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED) {
                    Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=com.google.android.apps.healthdata"))
                } else {
                    Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS)
                }
                runCatching { activity.startActivity(intent) }
                    .onSuccess { result.success(null) }
                    .onFailure { result.error("health_settings_unavailable", null, null) }
            }
            "readChanges" -> run(result) { readChanges(call) }
            "readDailyTotals" -> run(result) { readDailyTotals(call) }
            "write" -> run(result) { write(call) }
            "delete" -> run(result) { delete(call) }
            // The first public release refreshes connected fitness data only
            // while BIL is in use. Do not claim a continuous background job.
            "enableBackgroundDelivery" -> result.success(mapOf("enabled" to false, "contract" to "foreground-refresh-only"))
            else -> result.notImplemented()
        }
    }

    /** No DataOrigin filter: include phone steps and honor the user's app priorities. */
    private suspend fun readDailyTotals(call: MethodCall): List<Map<String, Any>> {
        val healthClient = requireClient()
        val permissions = healthClient.permissionController.getGrantedPermissions()
        val metrics = mutableSetOf<AggregateMetric<*>>()
        if (HealthPermission.getReadPermission(StepsRecord::class) in permissions) metrics += StepsRecord.COUNT_TOTAL
        if (HealthPermission.getReadPermission(DistanceRecord::class) in permissions) metrics += DistanceRecord.DISTANCE_TOTAL
        if (HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class) in permissions) metrics += ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL
        if (metrics.isEmpty()) return emptyList()
        val asOf = call.argument<String>("asOf")?.let(Instant::parse) ?: Instant.now()
        val zone = ZoneId.systemDefault()
        val end = asOf.atZone(zone).toLocalDateTime()
        val start = end.toLocalDate().minusDays(29).atStartOfDay()
        val buckets = healthClient.aggregateGroupByPeriod(
            AggregateGroupByPeriodRequest(
                metrics = metrics,
                timeRangeFilter = TimeRangeFilter.between(start, end),
                timeRangeSlicer = Period.ofDays(1),
            ),
        )
        return buckets.flatMap { bucket ->
            val observedAt = minOf(bucket.endTime.atZone(zone).toInstant().minusMillis(1), asOf)
            fun row(type: String, value: Double?, unit: String): Map<String, Any>? {
                if (value == null || !value.isFinite() || value < 0) return null
                return mapOf(
                    "id" to "daily:$type:${bucket.startTime.toLocalDate()}",
                    "type" to type, "value" to value, "unit" to unit,
                    "observedAt" to observedAt.toString(),
                    "sourceId" to "health_connect.aggregate", "confidence" to 1.0,
                    "timeZoneId" to zone.id,
                    "attributes" to mapOf(
                        "aggregation" to "native_daily",
                        "sources" to bucket.result.dataOrigins.map { it.packageName }.sorted(),
                    ),
                )
            }
            listOfNotNull(
                row("steps", bucket.result[StepsRecord.COUNT_TOTAL]?.toDouble(), "count"),
                row("distance", bucket.result[DistanceRecord.DISTANCE_TOTAL]?.inMeters, "m"),
                row("activeEnergy", bucket.result[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.inKilocalories, "kcal"),
            )
        }
    }

    private fun availability(): Int = HealthConnectClient.getSdkStatus(activity)

    private fun run(result: MethodChannel.Result, block: suspend () -> Any?) {
        scope.launch {
            try { result.success(withContext(Dispatchers.IO) { block() }) }
            catch (security: SecurityException) { result.error("unauthorized", security.message, mapOf("platform" to "health_connect")) }
            catch (error: Throwable) { result.error("health_connect_failure", error.message, mapOf("type" to error::class.java.simpleName)) }
        }
    }

    private suspend fun permissionSnapshot(names: List<String>): Map<String, Boolean> {
        val healthClient = requireClient()
        val granted = healthClient.permissionController.getGrantedPermissions()
        val recordPermissions = names.associateWith { name ->
            if (name !in supportedNames) false
            else recordClass(name)?.let { HealthPermission.getReadPermission(it) in granted } ?: false
        }
        // The durable Dart anchor belongs to both the record-type set and the
        // effective history window. If the user later grants (or revokes)
        // Additional access in Health Connect settings, this marker changes
        // the scope signature and forces one correctly bounded bootstrap.
        return recordPermissions + mapOf(
            HISTORY_PERMISSION_SCOPE_MARKER to
                (
                    healthClient.features.getFeatureStatus(
                        HealthConnectFeatures.FEATURE_READ_HEALTH_DATA_HISTORY,
                    ) == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE &&
                        HealthPermission.PERMISSION_READ_HEALTH_DATA_HISTORY in granted
                ),
        )
    }

    private fun requestPermissions(call: MethodCall, result: MethodChannel.Result) {
        if (pendingPermissionResult != null) {
            result.error("health_permission_request_in_progress", null, null)
            return
        }
        val names = call.argument<List<String>>("types") ?: supportedNames
        val write = call.argument<Boolean>("write") == true
        val recordPermissions = names
            .filter(supportedNames::contains)
            .mapNotNull(::recordClass)
            .flatMap { klass ->
                buildList {
                    add(HealthPermission.getReadPermission(klass))
                    if (write) add(HealthPermission.getWritePermission(klass))
                }
            }
            .toSet()
        // A one-year first import is useful for the trend screens and matches
        // the bounded HealthKit window. Health Connect history access remains
        // independently revocable: if it is declined, readChanges falls back
        // to the ordinary 30-day window instead of failing the connection.
        val historyReadAvailable = client?.features?.getFeatureStatus(
            HealthConnectFeatures.FEATURE_READ_HEALTH_DATA_HISTORY,
        ) == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE
        val permissions = if (
            !write && recordPermissions.isNotEmpty() && historyReadAvailable
        ) {
            recordPermissions + HealthPermission.PERMISSION_READ_HEALTH_DATA_HISTORY
        } else {
            recordPermissions
        }
        pendingPermissionResult = result
        permissionLauncher.launch(permissions)
    }

    fun onPermissionsResult(granted: Set<String>) {
        val result = pendingPermissionResult ?: return
        pendingPermissionResult = null
        result.success(mapOf("granted" to granted.size))
    }

    private suspend fun readChanges(call: MethodCall): Map<String, Any?> {
        val client = requireClient()
        val names = call.argument<List<String>>("types") ?: supportedNames
        val supportedRequestedNames = names.filter(supportedNames::contains).distinct()
        val requestedNameSet = supportedRequestedNames.toSet()
        val classes = supportedRequestedNames.mapNotNull(::recordClass).toSet()
        val incomingToken = call.argument<String>("anchor")
        val asOf = call.argument<String>("asOf")
            ?.let { raw -> runCatching { Instant.parse(raw) }.getOrNull() }
            ?: Instant.now()
        // Establish the incremental boundary before the first historical read.
        // Otherwise a record inserted between history and token creation can
        // fall through both windows and never be imported.
        val token = incomingToken ?: client.getChangesToken(ChangesTokenRequest(classes))
        // A changes token only observes mutations after it is created. Read a
        // bounded history for every requested type on the first synchronization
        // so existing sleep/activity/watch records are not invisible forever.
        val records = mutableListOf<Map<String, Any?>>()
        if (incomingToken == null) {
            val granted = client.permissionController.getGrantedPermissions()
            val historyReadAvailable = client.features.getFeatureStatus(
                HealthConnectFeatures.FEATURE_READ_HEALTH_DATA_HISTORY,
            ) == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE
            val historyDays = if (
                historyReadAvailable &&
                HealthPermission.PERMISSION_READ_HEALTH_DATA_HISTORY in granted
            ) 365L else 30L
            // History remains least-privilege. A denied history grant never
            // blocks current data: it simply selects Health Connect's ordinary
            // 30-day window instead of the explicitly authorized one-year view.
            val since = TimeRangeFilter.between(
                asOf.minusSeconds(historyDays * 24L * 60L * 60L),
                asOf,
            )
            suspend fun <T : Record> readInitial(recordType: KClass<T>) {
                var pageToken: String? = null
                do {
                    val page = client.readRecords(
                        ReadRecordsRequest(
                            recordType = recordType,
                            timeRangeFilter = since,
                            pageToken = pageToken,
                        ),
                    )
                    page.records.flatMapTo(records) { record ->
                        serializeAll(record, requestedNameSet)
                    }
                    pageToken = page.pageToken
                    // Some Health Connect implementations return an empty
                    // token at the end of pagination instead of null.
                } while (!pageToken.isNullOrEmpty())
            }
            for (name in supportedRequestedNames) when (name) {
                "steps" -> readInitial(StepsRecord::class)
                "distance" -> readInitial(DistanceRecord::class)
                "activeEnergy" -> readInitial(ActiveCaloriesBurnedRecord::class)
                "workout" -> readInitial(ExerciseSessionRecord::class)
                "sleep" -> readInitial(SleepSessionRecord::class)
                "weight" -> readInitial(WeightRecord::class)
                "bodyFat" -> readInitial(BodyFatRecord::class)
                "leanMass" -> readInitial(LeanBodyMassRecord::class)
                "heartRate" -> readInitial(HeartRateRecord::class)
                "restingHeartRate" -> readInitial(RestingHeartRateRecord::class)
                "hrv" -> readInitial(HeartRateVariabilityRmssdRecord::class)
                "water" -> readInitial(HydrationRecord::class)
            }
            if (supportedRequestedNames.any(nutritionLogicalNames::contains)) {
                readInitial(NutritionRecord::class)
            }
        }
        val response = client.getChanges(token)
        val deleted = mutableListOf<String>()
        response.changes.forEach { change ->
            when (change) {
                is DeletionChange -> deleted += change.recordId
                is UpsertionChange -> records += serializeAll(
                    change.record,
                    requestedNameSet,
                )
            }
        }
        return mapOf(
            "records" to records,
            "deletedIds" to deleted,
            "nextAnchor" to response.nextChangesToken,
            "hasMore" to response.hasMore,
            // Health Connect reports expired/invalid change tokens as a
            // response flag. Dart discards the durable anchor and performs one
            // bounded bootstrap; it must never save this unusable next token.
            "changesTokenExpired" to response.changesTokenExpired,
        )
    }

    private suspend fun write(call: MethodCall): Map<String, Any> {
        val rows = call.argument<List<Map<String, Any?>>>("signals") ?: emptyList()
        val records = rows.mapNotNull(::parseWritable)
        if (records.isNotEmpty()) requireClient().insertRecords(records)
        return mapOf("written" to records.size)
    }

    private suspend fun delete(call: MethodCall): Map<String, Any> {
        val ids = call.argument<List<String>>("recordIds") ?: emptyList()
        var deleted = 0
        for (klass in supportedNames.mapNotNull(::recordClass).toSet()) {
            if (ids.isNotEmpty()) { requireClient().deleteRecords(klass, ids, emptyList()); deleted += ids.size }
        }
        return mapOf("deleted" to deleted)
    }

    private fun serializeAll(
        record: Record,
        requestedNames: Set<String>,
    ): List<Map<String, Any?>> {
        val metadata = record.metadata
        // Health Connect explicitly recommends ignoring records written by the
        // calling app. Re-importing them would create an echo loop and could
        // falsely make the native source look connected after a local export.
        if (metadata.dataOrigin.packageName == activity.packageName) return emptyList()
        val device = metadata.device
        val provenanceAttributes = mutableMapOf<String, Any?>()
        device?.manufacturer?.trim()?.takeIf { it.isNotEmpty() }?.let {
            provenanceAttributes["deviceManufacturer"] = it
        }
        device?.model?.trim()?.takeIf { it.isNotEmpty() }?.let {
            provenanceAttributes["deviceModel"] = it
        }
        if (device?.type == androidx.health.connect.client.records.metadata.Device.TYPE_WATCH) {
            provenanceAttributes["wearableKind"] = "wear_os_watch"
        }
        val base = mutableMapOf<String, Any?>(
            "id" to metadata.id,
            "sourceId" to metadata.dataOrigin.packageName,
            "deviceId" to device?.model,
            "confidence" to 1.0,
            "timeZoneId" to "UTC",
            "deleted" to false,
        )
        fun output(
            type: String,
            value: Double,
            unit: String,
            observedAt: Instant,
            attributes: Map<String, Any?> = provenanceAttributes,
            recordId: String = metadata.id,
        ): Map<String, Any?> = base + mapOf(
            "id" to recordId,
            "type" to type,
            "value" to value,
            "unit" to unit,
            "observedAt" to observedAt.toString(),
            "attributes" to attributes,
        )
        fun single(name: String, row: Map<String, Any?>?): List<Map<String, Any?>> =
            if (name in requestedNames && row != null) listOf(row) else emptyList()
        return when (record) {
            is StepsRecord -> single("steps", output("steps", record.count.toDouble(), "count", record.startTime))
            is DistanceRecord -> single("distance", output("distance", record.distance.inMeters, "m", record.startTime))
            is WeightRecord -> single("weight", output("weight", record.weight.inKilograms, "kg", record.time))
            is BodyFatRecord -> single("bodyFat", output("bodyFat", record.percentage.value, "%", record.time))
            is LeanBodyMassRecord -> single("leanMass", output("leanMass", record.mass.inKilograms, "kg", record.time))
            is ActiveCaloriesBurnedRecord -> single("activeEnergy", output("activeEnergy", record.energy.inKilocalories, "kcal", record.startTime))
            is HeartRateRecord -> if ("heartRate" !in requestedNames) {
                emptyList()
            } else {
                // HeartRateRecord is a series, not one observation. Keep every
                // sample and give it a deterministic child identity. The
                // parent id lets Dart replace the whole series on an upsert and
                // remove every child when Health Connect emits one deletion.
                record.samples.mapIndexed { index, sample ->
                    output(
                        "heartRate",
                        sample.beatsPerMinute.toDouble(),
                        "count/min",
                        sample.time,
                        attributes = provenanceAttributes + mapOf(
                            "parentRecordId" to metadata.id,
                            "seriesSampleIndex" to index,
                        ),
                        recordId = "${metadata.id}#heartRate#${sample.time.toEpochMilli()}#$index",
                    )
                }
            }
            is RestingHeartRateRecord -> single("restingHeartRate", output("restingHeartRate", record.beatsPerMinute.toDouble(), "count/min", record.time))
            is HeartRateVariabilityRmssdRecord -> single("hrv", output("hrv", record.heartRateVariabilityMillis, "ms", record.time))
            is HydrationRecord -> single("water", output("water", record.volume.inLiters * 1000.0, "mL", record.startTime))
            is SleepSessionRecord -> single("sleep", output(
                "sleep",
                java.time.Duration.between(record.startTime, record.endTime).toMillis() / 3_600_000.0,
                "h",
                record.startTime,
                attributes = provenanceAttributes + mapOf(
                    "sessionId" to metadata.id,
                    "endedAt" to record.endTime.toString(),
                    "endTimeZoneOffset" to record.endZoneOffset?.id,
                    "stages" to record.stages.map { stage -> mapOf(
                        "stage" to stage.stage,
                        "startedAt" to stage.startTime.toString(),
                        "endedAt" to stage.endTime.toString(),
                    ) },
                ).filterValues { it != null },
            ) + mapOf(
                "timeZoneId" to (record.startZoneOffset?.id ?: "UTC"),
            ))
            is ExerciseSessionRecord -> single("workout", output("workout", java.time.Duration.between(record.startTime, record.endTime).seconds.toDouble(), "s", record.startTime))
            is NutritionRecord -> {
                val attributes = provenanceAttributes + mapOf(
                    "foodName" to record.name,
                    "mealType" to record.mealType,
                    "proteinGrams" to record.protein?.inGrams,
                    "carbohydrateGrams" to record.totalCarbohydrate?.inGrams,
                    "fatGrams" to record.totalFat?.inGrams,
                ).filterValues { it != null }
                buildList {
                    fun addNutrient(name: String, value: Double?, unit: String = "g") {
                        if (name in requestedNames && value != null) {
                            add(output(name, value, unit, record.startTime, attributes))
                        }
                    }
                    addNutrient("nutrition", record.energy?.inKilocalories, "kcal")
                    addNutrient("nutritionProtein", record.protein?.inGrams)
                    addNutrient("nutritionCarbohydrates", record.totalCarbohydrate?.inGrams)
                    addNutrient("nutritionFat", record.totalFat?.inGrams)
                    addNutrient("nutritionFiber", record.dietaryFiber?.inGrams)
                    addNutrient("nutritionSugar", record.sugar?.inGrams)
                    addNutrient("nutritionSodium", record.sodium?.inGrams?.times(1000.0), "mg")
                    addNutrient("nutritionPotassium", record.potassium?.inGrams?.times(1000.0), "mg")
                }
            }
            else -> emptyList()
        }
    }

    private fun parseWritable(row: Map<String, Any?>): Record? {
        val type = row["key"] as? String ?: return null
        val value = (row["canonicalValue"] as? Number)?.toDouble() ?: return null
        val at = (row["observedAt"] as? String)?.let(Instant::parse) ?: Instant.now()
        val metadata = androidx.health.connect.client.records.metadata.Metadata.manualEntry()
        val attributes = row["attributes"] as? Map<*, *> ?: emptyMap<Any, Any>()
        fun grams(name: String) = (attributes[name] as? Number)?.toDouble()?.takeIf { it >= 0.0 }
        return when (type) {
            "weight" -> WeightRecord(at, ZoneOffset.UTC, androidx.health.connect.client.units.Mass.kilograms(value), metadata)
            "nutrition" -> NutritionRecord(
                startTime = at,
                startZoneOffset = ZoneOffset.UTC,
                endTime = at.plusSeconds(1),
                endZoneOffset = ZoneOffset.UTC,
                metadata = metadata,
                energy = androidx.health.connect.client.units.Energy.kilocalories(value),
                protein = grams("proteinGrams")?.let(androidx.health.connect.client.units.Mass::grams),
                totalCarbohydrate = grams("carbohydrateGrams")?.let(androidx.health.connect.client.units.Mass::grams),
                totalFat = grams("fatGrams")?.let(androidx.health.connect.client.units.Mass::grams),
                name = (attributes["foodName"] as? String)?.trim()?.takeIf { it.isNotEmpty() },
                mealType = (attributes["mealType"] as? Number)?.toInt() ?: MealType.MEAL_TYPE_UNKNOWN,
            )
            else -> null
        }
    }

    private fun recordClass(name: String): kotlin.reflect.KClass<out Record>? = when (name) {
        "steps" -> StepsRecord::class
        "distance" -> DistanceRecord::class
        "activeEnergy" -> ActiveCaloriesBurnedRecord::class
        "workout" -> ExerciseSessionRecord::class
        "sleep" -> SleepSessionRecord::class
        "weight" -> WeightRecord::class
        "bodyFat" -> BodyFatRecord::class
        "leanMass" -> LeanBodyMassRecord::class
        "heartRate" -> HeartRateRecord::class
        "restingHeartRate" -> RestingHeartRateRecord::class
        "hrv" -> HeartRateVariabilityRmssdRecord::class
        "water" -> HydrationRecord::class
        in nutritionLogicalNames -> NutritionRecord::class
        else -> null
    }

    private fun requireClient(): HealthConnectClient = client ?: error("Health Connect SDK is unavailable or requires an update.")

    fun dispose() {
        pendingPermissionResult?.error("activity_disposed", null, null)
        pendingPermissionResult = null
        channel.setMethodCallHandler(null)
        scope.cancel()
    }

    companion object {
        const val CHANNEL = "bil/health_connect"
        const val HISTORY_PERMISSION_SCOPE_MARKER = "__readHealthDataHistory"
        val nutritionLogicalNames = setOf(
            "nutrition", "nutritionProtein", "nutritionCarbohydrates",
            "nutritionFat", "nutritionFiber", "nutritionSugar",
            "nutritionSodium", "nutritionPotassium",
        )
        val supportedNames = listOf(
            "steps", "distance", "activeEnergy", "workout", "sleep", "weight",
            "bodyFat", "leanMass", "heartRate", "restingHeartRate", "hrv",
            "water", "nutrition", "nutritionProtein", "nutritionCarbohydrates",
            "nutritionFat", "nutritionFiber", "nutritionSugar",
            "nutritionSodium", "nutritionPotassium",
        )
        fun permissionContract(activity: Activity) = PermissionController.createRequestPermissionResultContract()
    }
}
