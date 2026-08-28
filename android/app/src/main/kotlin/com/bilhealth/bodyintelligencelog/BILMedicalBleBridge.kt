package com.bilhealth.bodyintelligencelog

import android.Manifest
import android.bluetooth.*
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
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

class BILMedicalBleBridge(private val context: Context, messenger: BinaryMessenger, private val permissionRequester: ((MethodChannel.Result) -> Unit)? = null) {
  private val channel = MethodChannel(messenger, CHANNEL)
  private val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
  private val devices = ConcurrentHashMap<String, BluetoothDevice>()
  private val deviceProfiles = ConcurrentHashMap<String, Set<String>>()
  private val sessions = ConcurrentHashMap<String, BluetoothGatt>()
  private val seen = ConcurrentHashMap.newKeySet<String>()
  private val handler = Handler(Looper.getMainLooper())
  // Production scope: compatible fitness scales, body-composition devices,
  // heart-rate sensors and Pulse Oximeter Service (wellness display only).
  private val services = setOf("181D", "181B", "180D")
  private val measurementCharacteristics = setOf("2A9D", "2A9C", "2A37")

  companion object { const val CHANNEL = "bil.global/medical_ble" }

  init {
    channel.setMethodCallHandler { call, result ->
      val adapter = manager.adapter ?: return@setMethodCallHandler result.error("bluetooth_unavailable", null, null)
      if (!adapter.isEnabled) return@setMethodCallHandler result.error("bluetooth_disabled", null, null)
      if (call.method == "requestPermissions") { permissionRequester?.invoke(result) ?: result.error("permission_request_unavailable", null, null); return@setMethodCallHandler }
      if (!hasPermission()) return@setMethodCallHandler result.error("bluetooth_permission_denied", null, null)
      when (call.method) {
        "discover" -> discover(adapter, call.argument<Int>("timeoutMs") ?: 3000, result)
        "pair" -> pair(call.argument<String>("peripheralId"), result)
        "disconnect" -> disconnect(call.argument<String>("peripheralId"), result)
        "cancel" -> disconnect(call.argument<String>("peripheralId"), result)
        "deviceStatus" -> result.success(mapOf(
          "connected" to sessions.containsKey(call.argument<String>("peripheralId")),
          "batteryPercent" to null,
          "batteryVerified" to false,
        ))
        "forget" -> {
          val id = call.argument<String>("peripheralId")
          id?.let {
            val gatt = sessions.remove(it)
            gatt?.disconnect()
            gatt?.close()
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
    val replied = AtomicBoolean(false)
    val callback = object : ScanCallback() {
      override fun onScanResult(type: Int, scan: ScanResult) {
        val advertised = (scan.scanRecord?.serviceUuids ?: emptyList())
          .map { shortUuid(it.uuid.toString()) }
          .filter { services.contains(it) }
          .toSet()
        if (advertised.isNotEmpty()) {
          devices[scan.device.address] = scan.device
          deviceProfiles[scan.device.address] = advertised
        }
      }
      override fun onScanFailed(errorCode: Int) { if (replied.compareAndSet(false, true)) result.error("scan_failed", errorCode.toString(), null) }
    }
    adapter.bluetoothLeScanner.startScan(callback)
    handler.postDelayed({
      adapter.bluetoothLeScanner.stopScan(callback)
      if (replied.compareAndSet(false, true)) result.success(devices.values.map(::describe))
    }, timeoutMs.coerceIn(500, 30000).toLong())
  }

  private fun pair(id: String?, result: MethodChannel.Result) {
    // Standard fitness GATT sensors commonly do not create an Android system
    // bond. The real connection and any platform security prompt happen in
    // read(), so discovery must not fail merely because createBond() is not
    // supported by the peripheral.
    if (id?.let(devices::get) == null) return result.error("device_not_found", null, null)
    result.success(null)
  }

  private fun disconnect(id: String?, result: MethodChannel.Result) {
    id?.let { sessions.remove(it) }?.let { it.disconnect(); it.close() }
    result.success(null)
  }

  private fun read(id: String?, result: MethodChannel.Result) {
    val device = id?.let(devices::get) ?: return result.error("device_not_found", null, null)
    sessions.remove(device.address)?.let { it.disconnect(); it.close() }
    val replied = AtomicBoolean(false)
    val awaitingNotification = AtomicBoolean(false)
    val packets = mutableListOf<Map<String, Any>>()
    val pending = mutableListOf<BluetoothGattCharacteristic>()
    fun finish(error: String? = null) {
      if (!replied.compareAndSet(false, true)) return
      sessions.remove(device.address)?.let { it.disconnect(); it.close() }
      if (error == null) result.success(packets.toList()) else result.error(error, null, null)
    }
    val callback = object : BluetoothGattCallback() {
      override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, state: Int) {
        if (status != BluetoothGatt.GATT_SUCCESS) return finish("gatt_connection_failed")
        if (state == BluetoothProfile.STATE_CONNECTED) gatt.discoverServices()
        else if (state == BluetoothProfile.STATE_DISCONNECTED) finish(if (packets.isEmpty()) "gatt_disconnected" else null)
      }
      override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
        if (status != BluetoothGatt.GATT_SUCCESS) return finish("service_discovery_failed")
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
        if (pending.isEmpty()) return finish("no_supported_characteristic")
        readNext(gatt, pending, packets, awaitingNotification, ::finish)
      }
      @Deprecated("Deprecated by Android API; retained for min SDK compatibility")
      override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
        onPacket(gatt, characteristic, characteristic.value ?: byteArrayOf(), status, packets, pending, awaitingNotification, ::finish)
      }
      override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray, status: Int) {
        onPacket(gatt, characteristic, value, status, packets, pending, awaitingNotification, ::finish)
      }
      @Deprecated("Deprecated by Android API; retained for min SDK compatibility")
      override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
        onNotification(gatt, characteristic, characteristic.value ?: byteArrayOf(), packets, ::finish)
      }
      override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
        onNotification(gatt, characteristic, value, packets, ::finish)
      }
      override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
        if (status != BluetoothGatt.GATT_SUCCESS) return finish("notification_subscription_failed")
        readNext(gatt, pending, packets, awaitingNotification, ::finish)
      }
    }
    val gatt = device.connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE)
    sessions[device.address] = gatt
    handler.postDelayed({ finish("gatt_timeout") }, 20000)
  }

  private fun onPacket(gatt: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray, status: Int, packets: MutableList<Map<String, Any>>, pending: MutableList<BluetoothGattCharacteristic>, awaitingNotification: AtomicBoolean, finish: (String?) -> Unit) {
    if (status == BluetoothGatt.GATT_SUCCESS && value.isNotEmpty()) {
      val key = "${gatt.device.address}:${c.uuid}:${value.contentHashCode()}"
      if (seen.add(key)) packets += mapOf("peripheralId" to gatt.device.address, "service" to c.service.uuid.toString(), "characteristic" to c.uuid.toString(), "packet" to android.util.Base64.encodeToString(value, android.util.Base64.NO_WRAP), "receivedAt" to Instant.now().toString())
    }
    readNext(gatt, pending, packets, awaitingNotification, finish)
  }

  private fun onNotification(gatt: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray, packets: MutableList<Map<String, Any>>, finish: (String?) -> Unit) {
    if (value.isEmpty()) return
    val key = "${gatt.device.address}:${c.uuid}:${value.contentHashCode()}"
    if (seen.add(key)) packets += mapOf("peripheralId" to gatt.device.address, "service" to c.service.uuid.toString(), "characteristic" to c.uuid.toString(), "packet" to android.util.Base64.encodeToString(value, android.util.Base64.NO_WRAP), "receivedAt" to Instant.now().toString())
    finish(null)
  }

  @Suppress("DEPRECATION")
  private fun readNext(gatt: BluetoothGatt, pending: MutableList<BluetoothGattCharacteristic>, packets: MutableList<Map<String, Any>>, awaitingNotification: AtomicBoolean, finish: (String?) -> Unit) {
    if (pending.isEmpty()) {
      if (packets.isNotEmpty()) finish(null)
      else if (!awaitingNotification.get()) finish("no_measurement_received")
      return
    }
    val next = pending.removeAt(0)
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
  }

  private fun shortUuid(value: String) = value.substring(4, 8).uppercase()
  private fun describe(device: BluetoothDevice): Map<String, Any> = mapOf(
    "id" to device.address,
    "name" to (device.name ?: "Fitness device"),
    "manufacturer" to "unknown",
    "firmwareVersion" to "unknown",
    "profiles" to (deviceProfiles[device.address] ?: emptySet<String>()).toList(),
  )
}
