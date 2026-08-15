package com.kadem.bil

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.changes.DeletionChange
import androidx.health.connect.client.changes.UpsertionChange
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import androidx.health.connect.client.request.ChangesTokenRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.Instant
import java.time.ZoneOffset

/** Production Health Connect bridge. Device/OEM certification is tracked separately. */
class BILGlobalHealthBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
    private val permissionLauncher: ActivityResultLauncher<Set<String>>,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
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
            "write" -> run(result) { write(call) }
            "delete" -> run(result) { delete(call) }
            "enableBackgroundDelivery" -> result.success(mapOf("enabled" to true, "contract" to "workmanager-scheduler"))
            else -> result.notImplemented()
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
        val granted = requireClient().permissionController.getGrantedPermissions()
        return names.associateWith { name -> recordClass(name)?.let { HealthPermission.getReadPermission(it) in granted } ?: false }
    }

    private fun requestPermissions(call: MethodCall, result: MethodChannel.Result) {
        val names = call.argument<List<String>>("types") ?: supportedNames
        val write = call.argument<Boolean>("write") == true
        val permissions = names.mapNotNull(::recordClass).flatMap { klass ->
            buildList { add(HealthPermission.getReadPermission(klass)); if (write) add(HealthPermission.getWritePermission(klass)) }
        }.toSet()
        permissionLauncher.launch(permissions)
        result.success(mapOf("requested" to permissions.size))
    }

    private suspend fun readChanges(call: MethodCall): Map<String, Any?> {
        val client = requireClient()
        val names = call.argument<List<String>>("types") ?: supportedNames
        val classes = names.mapNotNull(::recordClass).toSet()
        val incomingToken = call.argument<String>("anchor")
        val token = incomingToken ?: client.getChangesToken(ChangesTokenRequest(classes))
        val response = client.getChanges(token)
        val records = mutableListOf<Map<String, Any?>>()
        val deleted = mutableListOf<String>()
        response.changes.forEach { change ->
            when (change) {
                is DeletionChange -> deleted += change.recordId
                is UpsertionChange -> serialize(change.record)?.let(records::add)
            }
        }
        return mapOf("records" to records, "deletedIds" to deleted, "nextAnchor" to response.nextChangesToken, "hasMore" to response.hasMore)
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

    private fun serialize(record: Record): Map<String, Any?>? {
        val metadata = record.metadata
        val base = mutableMapOf<String, Any?>(
            "id" to metadata.id,
            "sourceId" to metadata.dataOrigin.packageName,
            "deviceId" to metadata.device?.model,
            "confidence" to 1.0,
            "timeZoneId" to "UTC",
            "deleted" to false,
        )
        fun output(type: String, value: Double, unit: String, observedAt: Instant): Map<String, Any?> = base + mapOf("type" to type, "value" to value, "unit" to unit, "observedAt" to observedAt.toString())
        return when (record) {
            is StepsRecord -> output("steps", record.count.toDouble(), "count", record.startTime)
            is WeightRecord -> output("weight", record.weight.inKilograms, "kg", record.time)
            is ActiveCaloriesBurnedRecord -> output("activeEnergy", record.energy.inKilocalories, "kcal", record.startTime)
            is RestingHeartRateRecord -> output("restingHeartRate", record.beatsPerMinute.toDouble(), "count/min", record.time)
            is HeartRateVariabilityRmssdRecord -> output("hrv", record.heartRateVariabilityMillis, "ms", record.time)
            is OxygenSaturationRecord -> output("oxygen", record.percentage.value, "%", record.time)
            is RespiratoryRateRecord -> output("respiratoryRate", record.rate, "count/min", record.time)
            is BloodGlucoseRecord -> output("glucose", record.level.inMilligramsPerDeciliter, "mg/dL", record.time)
            is HydrationRecord -> output("water", record.volume.inLiters * 1000.0, "mL", record.startTime)
            is SleepSessionRecord -> output("sleep", java.time.Duration.between(record.startTime, record.endTime).seconds.toDouble(), "s", record.startTime)
            is ExerciseSessionRecord -> output("workout", java.time.Duration.between(record.startTime, record.endTime).seconds.toDouble(), "s", record.startTime)
            else -> null
        }
    }

    private fun parseWritable(row: Map<String, Any?>): Record? {
        val type = row["key"] as? String ?: return null
        val value = (row["canonicalValue"] as? Number)?.toDouble() ?: return null
        val at = (row["observedAt"] as? String)?.let(Instant::parse) ?: Instant.now()
        val metadata = androidx.health.connect.client.records.metadata.Metadata.manualEntry()
        return when (type) {
            "weight" -> WeightRecord(at, ZoneOffset.UTC, androidx.health.connect.client.units.Mass.kilograms(value), metadata)
            else -> null
        }
    }

    private fun recordClass(name: String): kotlin.reflect.KClass<out Record>? = when (name) {
        "steps" -> StepsRecord::class
        "activeEnergy" -> ActiveCaloriesBurnedRecord::class
        "workout" -> ExerciseSessionRecord::class
        "sleep" -> SleepSessionRecord::class
        "weight" -> WeightRecord::class
        "heartRate" -> HeartRateRecord::class
        "restingHeartRate" -> RestingHeartRateRecord::class
        "hrv" -> HeartRateVariabilityRmssdRecord::class
        "oxygen" -> OxygenSaturationRecord::class
        "respiratoryRate" -> RespiratoryRateRecord::class
        "glucose" -> BloodGlucoseRecord::class
        "bloodPressureSystolic", "bloodPressureDiastolic" -> BloodPressureRecord::class
        "water" -> HydrationRecord::class
        "nutrition" -> NutritionRecord::class
        else -> null
    }

    private fun requireClient(): HealthConnectClient = client ?: error("Health Connect SDK is unavailable or requires an update.")

    companion object {
        const val CHANNEL = "bil/health_connect"
        val supportedNames = listOf("steps", "activeEnergy", "workout", "weight")
        fun permissionContract(activity: Activity) = PermissionController.createRequestPermissionResultContract()
    }
}
