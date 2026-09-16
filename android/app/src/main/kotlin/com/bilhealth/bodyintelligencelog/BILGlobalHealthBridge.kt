package com.bilhealth.bodyintelligencelog

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.util.Base64
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.changes.DeletionChange
import androidx.health.connect.client.changes.UpsertionChange
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.StepsRecord
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
import java.time.ZoneId
import java.time.Period
import kotlin.reflect.KClass
import org.json.JSONObject

/** Production Health Connect bridge. Device/OEM certification is tracked separately. */
class BILGlobalHealthBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
    private val permissionLauncher: ActivityResultLauncher<Set<String>>,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var pendingPermissionResult: MethodChannel.Result? = null

    private data class BootstrapCursor(
        val changeToken: String,
        val asOf: Instant,
        val recordIndex: Int,
        val pageToken: String?,
    )

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
            "write", "delete" -> result.error(
                "health_connect_write_not_available",
                "Health Connect write access is not available in this release.",
                null,
            )
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
        return recordPermissions
    }

    private fun requestPermissions(call: MethodCall, result: MethodChannel.Result) {
        if (pendingPermissionResult != null) {
            result.error("health_permission_request_in_progress", null, null)
            return
        }
        val names = call.argument<List<String>>("types") ?: emptyList()
        if (call.argument<Boolean>("write") == true) {
            result.error("health_connect_write_not_available", null, null)
            return
        }
        val recordPermissions = names
            .filter(supportedNames::contains)
            .mapNotNull(::recordClass)
            .map { HealthPermission.getReadPermission(it) }
            .toSet()
        if (recordPermissions.isEmpty()) {
            result.success(mapOf("granted" to 0))
            return
        }
        pendingPermissionResult = result
        try {
            permissionLauncher.launch(recordPermissions)
        } catch (error: Exception) {
            pendingPermissionResult = null
            result.error("health_permission_request_failed", error.message, null)
        }
    }

    fun onPermissionsResult(granted: Set<String>) {
        val result = pendingPermissionResult ?: return
        pendingPermissionResult = null
        result.success(mapOf("granted" to granted.size))
    }

    private fun encodeBootstrapCursor(cursor: BootstrapCursor): String {
        val json = JSONObject()
            .put("change_token", cursor.changeToken)
            .put("as_of", cursor.asOf.toString())
            .put("record_index", cursor.recordIndex)
        cursor.pageToken?.let { json.put("page_token", it) }
        val encoded = Base64.encodeToString(
            json.toString().toByteArray(Charsets.UTF_8),
            Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
        )
        return BOOTSTRAP_ANCHOR_PREFIX + encoded
    }

    private fun decodeBootstrapCursor(anchor: String?): BootstrapCursor? {
        if (anchor == null || !anchor.startsWith(BOOTSTRAP_ANCHOR_PREFIX)) {
            return null
        }
        return runCatching {
            val encoded = anchor.removePrefix(BOOTSTRAP_ANCHOR_PREFIX)
            val decoded = String(
                Base64.decode(
                    encoded,
                    Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
                ),
                Charsets.UTF_8,
            )
            val json = JSONObject(decoded)
            val changeToken = json.getString("change_token").trim()
            val asOf = Instant.parse(json.getString("as_of"))
            val recordIndex = json.getInt("record_index")
            val pageToken = json.optString("page_token")
                .trim()
                .takeIf(String::isNotEmpty)
            require(changeToken.isNotEmpty())
            require(recordIndex >= 0)
            BootstrapCursor(
                changeToken = changeToken,
                asOf = asOf,
                recordIndex = recordIndex,
                pageToken = pageToken,
            )
        }.getOrNull()
    }

    private suspend fun readChanges(call: MethodCall): Map<String, Any?> {
        val client = requireClient()
        val names = call.argument<List<String>>("types") ?: emptyList()
        val granted = client.permissionController.getGrantedPermissions()
        val supportedRequestedNames = names.filter { name ->
            name in supportedNames &&
                recordClass(name)?.let { HealthPermission.getReadPermission(it) in granted } == true
        }.distinct()
        if (supportedRequestedNames.isEmpty()) {
            return mapOf(
                "records" to emptyList<Map<String, Any?>>(),
                "deletedIds" to emptyList<String>(),
                "nextAnchor" to null,
                "hasMore" to false,
                "changesTokenExpired" to false,
            )
        }
        val requestedNameSet = supportedRequestedNames.toSet()
        val classes = supportedRequestedNames.mapNotNull(::recordClass).toSet()
        val incomingAnchor = call.argument<String>("anchor")
        val bootstrapCursor = decodeBootstrapCursor(incomingAnchor)
        if (
            incomingAnchor?.startsWith(BOOTSTRAP_ANCHOR_PREFIX) == true &&
            bootstrapCursor == null
        ) {
            error("Invalid Health Connect bootstrap anchor.")
        }
        val requestedAsOf = call.argument<String>("asOf")
            ?.let { raw -> runCatching { Instant.parse(raw) }.getOrNull() }
            ?: Instant.now()
        // A paged bootstrap must keep the exact same time window across app
        // restarts. Health Connect page tokens are tied to the original query.
        val asOf = bootstrapCursor?.asOf ?: requestedAsOf
        // Establish the incremental boundary before the first historical read.
        // Otherwise a record inserted between history and token creation can
        // fall through both windows and never be imported.
        val token = bootstrapCursor?.changeToken
            ?: incomingAnchor
            ?: client.getChangesToken(ChangesTokenRequest(classes))
        val records = mutableListOf<Map<String, Any?>>()

        if (incomingAnchor == null || bootstrapCursor != null) {
            val since = TimeRangeFilter.between(
                asOf.minusSeconds(30L * 24L * 60L * 60L),
                asOf,
            )
            val bootstrapRecordNames = supportedRequestedNames
            var recordIndex = bootstrapCursor?.recordIndex ?: 0
            var pageToken = bootstrapCursor?.pageToken

            suspend fun <T : Record> readInitialPage(recordType: KClass<T>): String? {
                val page = client.readRecords(
                    ReadRecordsRequest(
                        recordType = recordType,
                        timeRangeFilter = since,
                        pageToken = pageToken,
                        pageSize = NATIVE_SYNC_PAGE_SIZE,
                    ),
                )
                page.records.flatMapTo(records) { record ->
                    serializeAll(record, requestedNameSet)
                }
                return page.pageToken?.trim()?.takeIf(String::isNotEmpty)
            }

            // Return at most one non-empty native history page per platform
            // message. Empty record families are skipped in the same call so a
            // sparse account does not pay a round trip for every supported type.
            while (recordIndex < bootstrapRecordNames.size) {
                val recordName = bootstrapRecordNames[recordIndex]
                val nextPageToken = when (recordName) {
                    "steps" -> readInitialPage(StepsRecord::class)
                    "distance" -> readInitialPage(DistanceRecord::class)
                    "activeEnergy" -> readInitialPage(ActiveCaloriesBurnedRecord::class)
                    else -> null
                }
                val nextIndex = if (nextPageToken == null) {
                    recordIndex + 1
                } else {
                    recordIndex
                }
                if (records.isNotEmpty() || nextPageToken != null) {
                    val cursor = BootstrapCursor(
                        changeToken = token,
                        asOf = asOf,
                        recordIndex = nextIndex,
                        pageToken = nextPageToken,
                    )
                    return mapOf(
                        "records" to records,
                        "deletedIds" to emptyList<String>(),
                        "nextAnchor" to encodeBootstrapCursor(cursor),
                        "hasMore" to true,
                        "changesTokenExpired" to false,
                    )
                }
                recordIndex = nextIndex
                pageToken = null
            }
        }

        // Once the bounded history is complete, drain one Health Connect
        // changes page. This SDK version exposes the one-argument getChanges()
        // API; response.hasMore and nextChangesToken keep the outer Dart loop
        // paged and restart-resumable without replaying the historical bootstrap.
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
            is ActiveCaloriesBurnedRecord -> single("activeEnergy", output("activeEnergy", record.energy.inKilocalories, "kcal", record.startTime))
            else -> emptyList()
        }
    }

    private fun recordClass(name: String): kotlin.reflect.KClass<out Record>? = when (name) {
        "steps" -> StepsRecord::class
        "distance" -> DistanceRecord::class
        "activeEnergy" -> ActiveCaloriesBurnedRecord::class
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
        private const val BOOTSTRAP_ANCHOR_PREFIX = "bil_hc_bootstrap_v1:"
        private const val NATIVE_SYNC_PAGE_SIZE = 250
        private val supportedNames = listOf(
            "steps", "distance", "activeEnergy",
        )
        fun permissionContract(activity: Activity) = PermissionController.createRequestPermissionResultContract()
    }
}
