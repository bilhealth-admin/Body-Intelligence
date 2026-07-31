package com.kadem.bil

import android.Manifest
import android.bluetooth.*
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
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
  private val sessions = ConcurrentHashMap<String, BluetoothGatt>()
  private val seen = ConcurrentHashMap.newKeySet<String>()
  private val handler = Handler(Looper.getMainLooper())
  private val services = setOf("1810", "1808", "181D", "181B", "1822", "180D", "1809")

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
      override fun onScanResult(type: Int, scan: ScanResult) { devices[scan.device.address] = scan.device }
      override fun onScanFailed(errorCode: Int) { if (replied.compareAndSet(false, true)) result.error("scan_failed", errorCode.toString(), null) }
    }
    adapter.bluetoothLeScanner.startScan(callback)
    handler.postDelayed({
      adapter.bluetoothLeScanner.stopScan(callback)
      if (replied.compareAndSet(false, true)) result.success(devices.values.map(::describe))
    }, timeoutMs.coerceIn(500, 30000).toLong())
  }

  private fun pair(id: String?, result: MethodChannel.Result) {
    val device = id?.let(devices::get) ?: return result.error("device_not_found", null, null)
    if (device.bondState == BluetoothDevice.BOND_BONDED) return result.success(null)
    val replied = AtomicBoolean(false)
    lateinit var receiver: BroadcastReceiver
    val timeout = Runnable {
      if (replied.compareAndSet(false, true)) {
        runCatching { context.unregisterReceiver(receiver) }
        result.error("pairing_timeout", null, null)
      }
    }
    receiver = object : BroadcastReceiver() {
      override fun onReceive(contextValue: Context?, intent: Intent?) {
        val changed = intent?.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
        if (changed?.address != device.address) return
        when (intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.BOND_NONE)) {
          BluetoothDevice.BOND_BONDED -> if (replied.compareAndSet(false, true)) { handler.removeCallbacks(timeout); context.unregisterReceiver(this); result.success(null) }
          BluetoothDevice.BOND_NONE -> if (replied.compareAndSet(false, true)) { handler.removeCallbacks(timeout); context.unregisterReceiver(this); result.error("pairing_failed", null, null) }
        }
      }
    }
    context.registerReceiver(receiver, IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED))
    if (!device.createBond()) { context.unregisterReceiver(receiver); result.error("pairing_start_failed", null, null) } else handler.postDelayed(timeout, 30000)
  }

  private fun disconnect(id: String?, result: MethodChannel.Result) {
    id?.let { sessions.remove(it) }?.let { it.disconnect(); it.close() }
    result.success(null)
  }

  private fun read(id: String?, result: MethodChannel.Result) {
    val device = id?.let(devices::get) ?: return result.error("device_not_found", null, null)
    sessions.remove(device.address)?.let { it.disconnect(); it.close() }
    val replied = AtomicBoolean(false)
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
        pending += gatt.services.filter { services.contains(shortUuid(it.uuid.toString())) }.flatMap { service -> service.characteristics.filter { characteristic -> (characteristic.properties and BluetoothGattCharacteristic.PROPERTY_READ) != 0 } }
        readNext(gatt, pending, ::finish)
      }
      @Deprecated("Deprecated by Android API; retained for min SDK compatibility")
      override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
        onPacket(gatt, characteristic, characteristic.value ?: byteArrayOf(), status, packets, pending, ::finish)
      }
      override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray, status: Int) {
        onPacket(gatt, characteristic, value, status, packets, pending, ::finish)
      }
    }
    val gatt = device.connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE)
    sessions[device.address] = gatt
    handler.postDelayed({ finish("gatt_timeout") }, 20000)
  }

  private fun onPacket(gatt: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray, status: Int, packets: MutableList<Map<String, Any>>, pending: MutableList<BluetoothGattCharacteristic>, finish: (String?) -> Unit) {
    if (status == BluetoothGatt.GATT_SUCCESS && value.isNotEmpty()) {
      val key = "${gatt.device.address}:${c.uuid}:${value.contentHashCode()}"
      if (seen.add(key)) packets += mapOf("peripheralId" to gatt.device.address, "service" to c.service.uuid.toString(), "characteristic" to c.uuid.toString(), "packet" to android.util.Base64.encodeToString(value, android.util.Base64.NO_WRAP), "receivedAt" to Instant.now().toString())
    }
    readNext(gatt, pending, finish)
  }

  private fun readNext(gatt: BluetoothGatt, pending: MutableList<BluetoothGattCharacteristic>, finish: (String?) -> Unit) {
    if (pending.isEmpty()) return finish(null)
    val next = pending.removeAt(0)
    if (!gatt.readCharacteristic(next)) finish("characteristic_read_start_failed")
  }

  private fun shortUuid(value: String) = value.substring(4, 8).uppercase()
  private fun describe(device: BluetoothDevice): Map<String, Any> = mapOf("id" to device.address, "name" to (device.name ?: "Medical device"), "manufacturer" to "unknown", "firmwareVersion" to "unknown", "profiles" to services.toList())
}
