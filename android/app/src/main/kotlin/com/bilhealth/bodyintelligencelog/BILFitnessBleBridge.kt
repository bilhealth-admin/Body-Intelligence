package com.bilhealth.bodyintelligencelog

import android.Manifest
import android.bluetooth.*
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.BluetoothLeScanner
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.time.Instant
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

class BILFitnessBleBridge(private val context: Context, messenger: BinaryMessenger, private val permissionRequester: ((MethodChannel.Result) -> Unit)? = null) {
  private val channel = MethodChannel(messenger, CHANNEL)
  private val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
  private val devices = ConcurrentHashMap<String, BluetoothDevice>()
  private val deviceProfiles = ConcurrentHashMap<String, Set<String>>()
  private val sessions = ConcurrentHashMap<String, BluetoothGatt>()
  private val connectedSessions = ConcurrentHashMap<String, BluetoothGatt>()
  private val activeScans = ConcurrentHashMap<ScanCallback, BluetoothLeScanner>()
  private val handler = Handler(Looper.getMainLooper())
  // Production scope: compatible fitness scales, body-composition devices,
  // and heart-rate sensors only.
  private val services = setOf("181D", "181B", "180D")
  private val measurementCharacteristics = setOf("2A9D", "2A9C", "2A37")

  companion object { const val CHANNEL = "bil.global/fitness_ble" }

  init {
    channel.setMethodCallHandler { call, result ->
      if (call.method == "requestPermissions") {
        if (hasPermission()) {
          result.success(null)
        } else {
          permissionRequester?.invoke(result)
            ?: result.error("permission_request_unavailable", null, null)
        }
        return@setMethodCallHandler
      }
      if (!hasPermission()) return@setMethodCallHandler result.error("bluetooth_permission_denied", null, null)
      // Android 12+ protects adapter state behind BLUETOOTH_CONNECT. Never
      // touch the adapter before the permission gate above has succeeded.
      val adapter = try {
        manager.adapter
          ?: return@setMethodCallHandler result.error("bluetooth_unavailable", null, null)
      } catch (error: SecurityException) {
        return@setMethodCallHandler result.error(
          "bluetooth_permission_denied",
          error.message,
          null,
        )
      }
      try {
        if (!adapter.isEnabled) {
          return@setMethodCallHandler result.error("bluetooth_disabled", null, null)
        }
      } catch (error: SecurityException) {
        return@setMethodCallHandler result.error(
          "bluetooth_permission_denied",
          error.message,
          null,
        )
      }
      when (call.method) {
        "discover" -> discover(adapter, call.argument<Int>("timeoutMs") ?: 3000, result)
        "pair" -> pair(call.argument<String>("peripheralId"), result)
        "disconnect" -> disconnect(call.argument<String>("peripheralId"), result)
        "cancel" -> disconnect(call.argument<String>("peripheralId"), result)
        "deviceStatus" -> {
          val id = call.argument<String>("peripheralId")
          val active = id?.let(sessions::get)
          val connected = id != null && active != null && connectedSessions[id] === active
          result.success(mapOf(
            "connected" to connected,
            "batteryPercent" to null,
            "batteryVerified" to false,
          ))
        }
        "forget" -> {
          val id = call.argument<String>("peripheralId")
          id?.let {
            val gatt = sessions.remove(it)
            if (gatt != null) connectedSessions.remove(it, gatt)
            gatt?.let { closeGattSafely(it) }
            devices.remove(it)
            deviceProfiles.remove(it)
          }
          result.success(mapOf("forgottenLocally" to true, "systemUnpairRequired" to true))
        }
        "readMeasurements" -> read(call.argument<String>("peripheralId"), result)
        else -> result.notImplemented()
      }
    }
  }

  private fun hasPermission(): Boolean = if (android.os.Build.VERSION.SDK_INT >= 31) {
    ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED &&
      ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
  } else {
    ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
  }

  private fun discover(adapter: BluetoothAdapter, timeoutMs: Int, result: MethodChannel.Result) {
    val scanner = try {
      adapter.bluetoothLeScanner
        ?: return result.error("bluetooth_scanner_unavailable", null, null)
    } catch (error: SecurityException) {
      result.error("bluetooth_permission_denied", error.message, null)
      return
    }
    val replied = AtomicBoolean(false)
    // `devices` remains a short-lived lookup cache for a subsequent pair/read,
    // but discovery results must describe only this scan session. Returning the
    // whole cache made peripherals seen minutes ago look nearby.
    val discoveredIds = ConcurrentHashMap.newKeySet<String>()
    val callback = object : ScanCallback() {
      override fun onScanResult(type: Int, scan: ScanResult) {
        try {
          val advertised = (scan.scanRecord?.serviceUuids ?: emptyList())
            .map { shortUuid(it.uuid.toString()) }
            .filter { services.contains(it) }
            .toSet()
          if (advertised.isNotEmpty()) {
            val address = scan.device.address
            devices[address] = scan.device
            deviceProfiles[address] = advertised
            discoveredIds += address
          }
        } catch (_: SecurityException) {
          // Permission may be revoked between startScan and this callback.
        }
      }
      override fun onScanFailed(errorCode: Int) {
        activeScans.remove(this)
        if (replied.compareAndSet(false, true)) {
          result.error("scan_failed", errorCode.toString(), null)
        }
      }
    }
    activeScans[callback] = scanner
    try {
      scanner.startScan(callback)
    } catch (error: SecurityException) {
      activeScans.remove(callback)
      result.error("bluetooth_permission_denied", error.message, null)
      return
    } catch (error: IllegalStateException) {
      activeScans.remove(callback)
      result.error("bluetooth_scanner_unavailable", error.message, null)
      return
    }
    handler.postDelayed({
      activeScans.remove(callback)?.let { active ->
        try {
          active.stopScan(callback)
        } catch (_: SecurityException) {
          // Access may have been revoked while the bounded scan was active.
        } catch (_: IllegalStateException) {
          // The adapter may have been disabled while the scan was active.
        }
      }
      if (replied.compareAndSet(false, true)) {
        result.success(discoveredIds.mapNotNull(devices::get).map(::describe))
      }
    }, timeoutMs.coerceIn(500, 30000).toLong())
  }

  private fun pair(id: String?, result: MethodChannel.Result) {
    // Standard fitness GATT sensors commonly do not create an Android system
    // bond. Treat "pair" as a verified GATT connection, not as a successful
    // no-op: the UI must never claim a connection merely because discovery
    // found an address.
    val device = id?.let(devices::get) ?: return result.error("device_not_found", null, null)
    val address = try {
      device.address
    } catch (error: SecurityException) {
      result.error("bluetooth_permission_denied", error.message, null)
      return
    }
    val active = sessions[address]
    if (active != null && connectedSessions[address] === active) {
      result.success(null)
      return
    }
    sessions.remove(address)?.let { stale ->
      connectedSessions.remove(address, stale)
      closeGattSafely(stale)
    }
    val replied = AtomicBoolean(false)
    val callback = object : BluetoothGattCallback() {
      override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, state: Int) {
        if (status == BluetoothGatt.GATT_SUCCESS && state == BluetoothProfile.STATE_CONNECTED) {
          // A timeout, disconnect, or newer operation may already have
          // superseded this callback. Never resurrect its stale GATT handle.
          if (sessions[address] !== gatt) {
            connectedSessions.remove(address, gatt)
            sessions.remove(address, gatt)
            closeGattSafely(gatt)
            if (replied.compareAndSet(false, true)) {
              result.error("gatt_superseded", null, null)
            }
            return
          }
          connectedSessions[address] = gatt
          if (replied.compareAndSet(false, true)) result.success(null)
          return
        }
        connectedSessions.remove(address, gatt)
        sessions.remove(address, gatt)
        closeGattSafely(gatt, disconnectFirst = false)
        if (replied.compareAndSet(false, true)) {
          result.error(
            if (status == BluetoothGatt.GATT_SUCCESS) "gatt_disconnected" else "gatt_connection_failed",
            null,
            null,
          )
        }
      }
    }
    val gatt = try {
      device.connectGatt(
        context,
        false,
        callback,
        BluetoothDevice.TRANSPORT_LE,
        BluetoothDevice.PHY_LE_1M_MASK,
        handler,
      )
    } catch (error: SecurityException) {
      result.error("bluetooth_permission_denied", error.message, null)
      return
    }
    if (gatt == null) {
      result.error("gatt_unavailable", null, null)
      return
    }
    sessions[address] = gatt
    handler.postDelayed({
      if (!replied.compareAndSet(false, true)) return@postDelayed
      connectedSessions.remove(address, gatt)
      sessions.remove(address, gatt)
      closeGattSafely(gatt)
      result.error("pairing_timeout", null, null)
    }, 20000)
  }

  private fun disconnect(id: String?, result: MethodChannel.Result) {
    id?.let { deviceId ->
      sessions.remove(deviceId)?.let {
        connectedSessions.remove(deviceId, it)
        closeGattSafely(it)
      }
    }
    result.success(null)
  }

  private fun read(id: String?, result: MethodChannel.Result) {
    val device = id?.let(devices::get) ?: return result.error("device_not_found", null, null)
    val address = try {
      device.address
    } catch (error: SecurityException) {
      result.error("bluetooth_permission_denied", error.message, null)
      return
    }
    sessions.remove(address)?.let {
      connectedSessions.remove(address, it)
      closeGattSafely(it)
    }
    val replied = AtomicBoolean(false)
    val awaitingNotification = AtomicBoolean(false)
    val packets = mutableListOf<Map<String, Any>>()
    val pending = mutableListOf<BluetoothGattCharacteristic>()
    val seenPackets = mutableSetOf<String>()
    var operationGatt: BluetoothGatt? = null
    fun finish(error: String? = null) {
      if (!replied.compareAndSet(false, true)) return
      val owner = operationGatt
      val keepVerifiedConnection =
        error == null && owner != null && sessions[address] === owner &&
          connectedSessions[address] === owner
      // A successful read is still a live connection and backs the Dart/UI
      // `connected` state. Error and remote-disconnect paths are terminal and
      // must release the GATT handle.
      if (!keepVerifiedConnection && owner != null) {
        sessions.remove(address, owner)
        connectedSessions.remove(address, owner)
        closeGattSafely(owner)
      }
      if (error == null) result.success(packets.toList()) else result.error(error, null, null)
    }
    val callback = object : BluetoothGattCallback() {
      override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, state: Int) {
        if (status != BluetoothGatt.GATT_SUCCESS) {
          if (replied.get()) {
            connectedSessions.remove(address, gatt)
            sessions.remove(address, gatt)
            closeGattSafely(gatt, disconnectFirst = false)
          } else {
            finish("gatt_connection_failed")
          }
          return
        }
        if (state == BluetoothProfile.STATE_CONNECTED) {
          if (sessions[address] !== gatt) {
            connectedSessions.remove(address, gatt)
            sessions.remove(address, gatt)
            closeGattSafely(gatt)
            finish("gatt_superseded")
            return
          }
          if (replied.get()) return
          connectedSessions[address] = gatt
          try {
            if (!gatt.discoverServices()) finish("service_discovery_start_failed")
          } catch (_: SecurityException) {
            finish("bluetooth_permission_denied")
          }
        } else if (state == BluetoothProfile.STATE_DISCONNECTED) {
          if (replied.get()) {
            // A successful read intentionally retains its live GATT session;
            // a later remote disconnect must still clear that verified state.
            connectedSessions.remove(address, gatt)
            sessions.remove(address, gatt)
            closeGattSafely(gatt, disconnectFirst = false)
            return
          }
          val isCurrent = sessions[address] === gatt
          connectedSessions.remove(address, gatt)
          sessions.remove(address, gatt)
          closeGattSafely(gatt, disconnectFirst = false)
          if (replied.compareAndSet(false, true)) {
            when {
              !isCurrent -> result.error("gatt_superseded", null, null)
              packets.isEmpty() -> result.error("gatt_disconnected", null, null)
              else -> result.success(packets.toList())
            }
          }
        }
      }
      override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
        if (replied.get() || sessions[address] !== gatt) return
        if (status != BluetoothGatt.GATT_SUCCESS) return finish("service_discovery_failed")
        try {
          pending += gatt.services
            .filter { services.contains(shortUuid(it.uuid.toString())) }
            .flatMap { service ->
              service.characteristics.filter { characteristic ->
                val supported = measurementCharacteristics.contains(shortUuid(characteristic.uuid.toString()))
                val readable = (characteristic.properties and BluetoothGattCharacteristic.PROPERTY_READ) != 0
                val notifiable = (characteristic.properties and (BluetoothGattCharacteristic.PROPERTY_NOTIFY or BluetoothGattCharacteristic.PROPERTY_INDICATE)) != 0
                supported && (readable || notifiable)
              }
            }
        } catch (_: SecurityException) {
          finish("bluetooth_permission_denied")
          return
        }
        if (pending.isEmpty()) return finish("no_supported_characteristic")
        readNext(gatt, pending, packets, awaitingNotification, ::finish)
      }
      @Deprecated("Deprecated by Android API; retained for min SDK compatibility")
      override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
        if (replied.get() || sessions[address] !== gatt) return
        onPacket(address, gatt, characteristic, characteristic.value ?: byteArrayOf(), status, packets, pending, awaitingNotification, seenPackets, ::finish)
      }
      override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray, status: Int) {
        if (replied.get() || sessions[address] !== gatt) return
        onPacket(address, gatt, characteristic, value, status, packets, pending, awaitingNotification, seenPackets, ::finish)
      }
      @Deprecated("Deprecated by Android API; retained for min SDK compatibility")
      override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
        if (replied.get() || sessions[address] !== gatt) return
        onNotification(address, characteristic, characteristic.value ?: byteArrayOf(), packets, seenPackets, ::finish)
      }
      override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
        if (replied.get() || sessions[address] !== gatt) return
        onNotification(address, characteristic, value, packets, seenPackets, ::finish)
      }
      override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
        if (replied.get() || sessions[address] !== gatt) return
        if (status != BluetoothGatt.GATT_SUCCESS) return finish("notification_subscription_failed")
        readNext(gatt, pending, packets, awaitingNotification, ::finish)
      }
    }
    val gatt = try {
      device.connectGatt(
        context,
        false,
        callback,
        BluetoothDevice.TRANSPORT_LE,
        BluetoothDevice.PHY_LE_1M_MASK,
        handler,
      )
    } catch (error: SecurityException) {
      result.error("bluetooth_permission_denied", error.message, null)
      return
    }
    if (gatt == null) {
      result.error("gatt_unavailable", null, null)
      return
    }
    operationGatt = gatt
    sessions[address] = gatt
    handler.postDelayed({ finish("gatt_timeout") }, 20000)
  }

  private fun onPacket(peripheralId: String, gatt: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray, status: Int, packets: MutableList<Map<String, Any>>, pending: MutableList<BluetoothGattCharacteristic>, awaitingNotification: AtomicBoolean, seenPackets: MutableSet<String>, finish: (String?) -> Unit) {
    if (status == BluetoothGatt.GATT_SUCCESS && value.isNotEmpty()) {
      val key = "$peripheralId:${c.uuid}:${value.contentHashCode()}"
      if (seenPackets.add(key)) packets += mapOf("peripheralId" to peripheralId, "service" to c.service.uuid.toString(), "characteristic" to c.uuid.toString(), "packet" to android.util.Base64.encodeToString(value, android.util.Base64.NO_WRAP), "receivedAt" to Instant.now().toString())
    }
    readNext(gatt, pending, packets, awaitingNotification, finish)
  }

  private fun onNotification(peripheralId: String, c: BluetoothGattCharacteristic, value: ByteArray, packets: MutableList<Map<String, Any>>, seenPackets: MutableSet<String>, finish: (String?) -> Unit) {
    if (value.isEmpty()) return
    val key = "$peripheralId:${c.uuid}:${value.contentHashCode()}"
    if (seenPackets.add(key)) {
      packets += mapOf("peripheralId" to peripheralId, "service" to c.service.uuid.toString(), "characteristic" to c.uuid.toString(), "packet" to android.util.Base64.encodeToString(value, android.util.Base64.NO_WRAP), "receivedAt" to Instant.now().toString())
      finish(null)
    }
  }

  @Suppress("DEPRECATION")
  private fun readNext(gatt: BluetoothGatt, pending: MutableList<BluetoothGattCharacteristic>, packets: MutableList<Map<String, Any>>, awaitingNotification: AtomicBoolean, finish: (String?) -> Unit) {
    if (pending.isEmpty()) {
      if (packets.isNotEmpty()) finish(null)
      else if (!awaitingNotification.get()) finish("no_measurement_received")
      return
    }
    val next = pending.removeAt(0)
    try {
      if ((next.properties and BluetoothGattCharacteristic.PROPERTY_READ) != 0) {
        if (!gatt.readCharacteristic(next)) finish("characteristic_read_start_failed")
        return
      }
      val indicate = (next.properties and BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0
      val descriptor = next.getDescriptor(java.util.UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"))
      if (descriptor == null || !gatt.setCharacteristicNotification(next, true)) {
        finish("notification_subscription_unavailable")
        return
      }
      awaitingNotification.set(true)
      descriptor.value = if (indicate) BluetoothGattDescriptor.ENABLE_INDICATION_VALUE else BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
      if (!gatt.writeDescriptor(descriptor)) finish("notification_subscription_failed")
    } catch (_: SecurityException) {
      finish("bluetooth_permission_denied")
    }
  }

  private fun shortUuid(value: String) = value.substring(4, 8).uppercase()
  private fun describe(device: BluetoothDevice): Map<String, Any> {
    val address = try {
      device.address
    } catch (_: SecurityException) {
      "unknown"
    }
    val name = try {
      device.name ?: "Fitness device"
    } catch (_: SecurityException) {
      "Fitness device"
    }
    return mapOf(
      "id" to address,
      "name" to name,
      "manufacturer" to "unknown",
      "firmwareVersion" to "unknown",
      "profiles" to (deviceProfiles[address] ?: emptySet<String>()).toList(),
    )
  }

  private fun closeGattSafely(gatt: BluetoothGatt, disconnectFirst: Boolean = true) {
    if (disconnectFirst) {
      try {
        gatt.disconnect()
      } catch (_: SecurityException) {
        // BLUETOOTH_CONNECT can be revoked while an asynchronous GATT call is active.
      } catch (_: IllegalStateException) {
        // The Bluetooth process or adapter may already be shutting down.
      }
    }
    try {
      gatt.close()
    } catch (_: SecurityException) {
      // Closing must remain best-effort during engine teardown.
    } catch (_: IllegalStateException) {
      // The native handle may already be closed by a remote-disconnect callback.
    }
  }

  fun dispose() {
    handler.removeCallbacksAndMessages(null)
    activeScans.entries.toList().forEach { (callback, scanner) ->
      try {
        scanner.stopScan(callback)
      } catch (_: SecurityException) {
        // Permission can be revoked while the activity is shutting down.
      } catch (_: IllegalStateException) {
        // Adapter/scanner teardown races must not crash engine cleanup.
      }
    }
    activeScans.clear()
    sessions.values.toSet().forEach { closeGattSafely(it) }
    sessions.clear()
    connectedSessions.clear()
    devices.clear()
    deviceProfiles.clear()
    channel.setMethodCallHandler(null)
  }
}
