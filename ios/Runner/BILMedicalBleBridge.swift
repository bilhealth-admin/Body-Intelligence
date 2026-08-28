import CoreBluetooth
import Flutter

final class BILMedicalBleBridge: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
  static let channelName = "bil.global/medical_ble"
  private let channel: FlutterMethodChannel
  private var central: CBCentralManager!
  private var peripherals: [UUID: CBPeripheral] = [:]
  private var advertisedProfiles: [UUID: Set<String>] = [:]
  private var sessions: [UUID: ReadSession] = [:]
  private var discoveryResult: FlutterResult?
  private var seenPackets = Set<String>()
  private var pendingPairResults: [UUID: FlutterResult] = [:]

  private final class ReadSession {
    let result: FlutterResult
    var packets = [[String: Any]]()
    var expectedCharacteristics = Set<String>()
    var completedCharacteristics = Set<String>()
    var pendingServiceDiscoveries = 0
    var completed = false
    var timeout: DispatchWorkItem?
    init(result: @escaping FlutterResult) { self.result = result }
  }

  static func register(with registrar: FlutterPluginRegistrar) { _ = BILMedicalBleBridge(registrar: registrar) }
  init(registrar: FlutterPluginRegistrar) {
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: registrar.messenger())
    super.init(); central = CBCentralManager(delegate: self, queue: nil); channel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard central.state == .poweredOn else { result(FlutterError(code:"bluetooth_disabled", message:"Bluetooth unavailable", details:nil)); return }
    let args = call.arguments as? [String:Any] ?? [:]
    switch call.method {
    case "requestPermissions":
      // CoreBluetooth presents its system authorization prompt when scanning.
      result(nil)
    case "discover":
      guard discoveryResult == nil else { result(FlutterError(code:"operation_in_progress",message:nil,details:nil)); return }
      discoveryResult = result; central.scanForPeripherals(withServices: supportedServices, options:[CBCentralManagerScanOptionAllowDuplicatesKey:false])
      DispatchQueue.main.asyncAfter(deadline:.now()+3) { self.central.stopScan(); let callback=self.discoveryResult; self.discoveryResult=nil; callback?(self.peripherals.values.map(self.describe)) }
    case "pair":
      guard let p=peripheral(args) else { result(FlutterError(code:"not_found",message:nil,details:nil)); return }
      if p.state == .connected { result(nil); return }
      guard pendingPairResults[p.identifier] == nil else { result(FlutterError(code:"operation_in_progress",message:nil,details:nil)); return }
      pendingPairResults[p.identifier] = result
      central.connect(p)
      DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
        guard let callback = self?.pendingPairResults.removeValue(forKey: p.identifier) else { return }
        callback(FlutterError(code:"pairing_timeout",message:nil,details:nil))
        self?.central.cancelPeripheralConnection(p)
      }
    case "disconnect", "cancel":
      guard let p=peripheral(args) else { result(nil); return }; finish(p.identifier, error:nil); central.cancelPeripheralConnection(p); result(nil)
    case "deviceStatus":
      guard let p=peripheral(args) else { result(["connected":false,"batteryVerified":false]); return }
      result(["connected":p.state == .connected,"batteryPercent":NSNull(),"batteryVerified":false])
    case "forget":
      guard let p=peripheral(args) else { result(nil); return }
      finish(p.identifier,error:nil); central.cancelPeripheralConnection(p); peripherals.removeValue(forKey:p.identifier); advertisedProfiles.removeValue(forKey:p.identifier)
      result(["forgottenLocally":true,"systemUnpairRequired":false])
    case "readMeasurements":
      guard let p=peripheral(args) else { result(FlutterError(code:"not_found",message:nil,details:nil)); return }
      if sessions[p.identifier] != nil { result(FlutterError(code:"operation_in_progress",message:nil,details:nil)); return }
      let session=ReadSession(result:result); sessions[p.identifier]=session; p.delegate=self
      let timeout=DispatchWorkItem { [weak self] in self?.finish(p.identifier,error:FlutterError(code:"gatt_timeout",message:nil,details:nil)) }; session.timeout=timeout
      DispatchQueue.main.asyncAfter(deadline:.now()+20,execute:timeout)
      if p.state == .connected { p.discoverServices(supportedServices) } else { central.connect(p) }
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func peripheral(_ args:[String:Any])->CBPeripheral? { guard let id=args["peripheralId"] as? String, let uuid=UUID(uuidString:id) else{return nil}; return peripherals[uuid] }
  private var supportedServices:[CBUUID]{["181D","181B","180D"].map(CBUUID.init(string:))}
  private var supportedCharacteristics:Set<String>{["2A9D","2A9C","2A37"]}
  func centralManagerDidUpdateState(_ central:CBCentralManager) {}
  func centralManager(_ central:CBCentralManager,didDiscover peripheral:CBPeripheral,advertisementData:[String:Any],rssi RSSI:NSNumber){
    let supported = Set(supportedServices.map { $0.uuidString })
    let advertised = Set((advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []).map { $0.uuidString }.filter { supported.contains($0) })
    guard !advertised.isEmpty else { return }
    peripherals[peripheral.identifier]=peripheral; advertisedProfiles[peripheral.identifier]=advertised
  }
  func centralManager(_ central:CBCentralManager,didConnect peripheral:CBPeripheral){
    pendingPairResults.removeValue(forKey: peripheral.identifier)?(nil)
    peripheral.delegate=self
    if sessions[peripheral.identifier] != nil { peripheral.discoverServices(supportedServices) }
  }
  func centralManager(_ central:CBCentralManager,didFailToConnect peripheral:CBPeripheral,error:Error?){
    pendingPairResults.removeValue(forKey: peripheral.identifier)?(FlutterError(code:"pairing_failed",message:error?.localizedDescription,details:nil))
    finish(peripheral.identifier,error:FlutterError(code:"gatt_connection_failed",message:error?.localizedDescription,details:nil))
  }
  func centralManager(_ central:CBCentralManager,didDisconnectPeripheral peripheral:CBPeripheral,error:Error?){ if sessions[peripheral.identifier] != nil { finish(peripheral.identifier,error:error == nil ? nil : FlutterError(code:"gatt_disconnected",message:error?.localizedDescription,details:nil)) } }
  func peripheral(_ peripheral:CBPeripheral,didDiscoverServices error:Error?){
    if let error=error { finish(peripheral.identifier,error:FlutterError(code:"service_discovery_failed",message:error.localizedDescription,details:nil));return }
    guard let session=sessions[peripheral.identifier] else{return}
    let services = peripheral.services ?? []
    session.pendingServiceDiscoveries = services.count
    if services.isEmpty { finish(peripheral.identifier,error:nil); return }
    services.forEach{ peripheral.discoverCharacteristics(nil,for:$0) }
  }
  func peripheral(_ peripheral:CBPeripheral,didDiscoverCharacteristicsFor service:CBService,error:Error?){
    guard let session=sessions[peripheral.identifier] else{return}
    if let error=error { finish(peripheral.identifier,error:FlutterError(code:"characteristic_discovery_failed",message:error.localizedDescription,details:nil));return }
    let characteristics=(service.characteristics ?? []).filter {
      supportedCharacteristics.contains($0.uuid.uuidString) &&
        ($0.properties.contains(.read) || $0.properties.contains(.notify) || $0.properties.contains(.indicate))
    }
    for characteristic in characteristics { session.expectedCharacteristics.insert("\(service.uuid.uuidString):\(characteristic.uuid.uuidString)") }
    session.pendingServiceDiscoveries=max(0,session.pendingServiceDiscoveries-1)
    if session.pendingServiceDiscoveries == 0 {
      if session.expectedCharacteristics.isEmpty { finish(peripheral.identifier,error:FlutterError(code:"no_supported_characteristic",message:nil,details:nil)); return }
      for discoveredService in peripheral.services ?? [] {
        for characteristic in discoveredService.characteristics ?? [] where session.expectedCharacteristics.contains("\(discoveredService.uuid.uuidString):\(characteristic.uuid.uuidString)") {
          if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) { peripheral.setNotifyValue(true,for:characteristic) }
          if characteristic.properties.contains(.read) { peripheral.readValue(for:characteristic) }
        }
      }
    }
  }
  func peripheral(_ peripheral:CBPeripheral,didUpdateValueFor characteristic:CBCharacteristic,error:Error?){
    guard let session=sessions[peripheral.identifier] else{return}
    let identity="\(characteristic.service?.uuid.uuidString ?? ""):" + characteristic.uuid.uuidString
    guard session.expectedCharacteristics.contains(identity), !session.completedCharacteristics.contains(identity) else{return}
    session.completedCharacteristics.insert(identity)
    if error == nil, let data=characteristic.value {
      let key="\(peripheral.identifier)-\(characteristic.uuid)-\(data.base64EncodedString())"
      if seenPackets.insert(key).inserted { session.packets.append(["peripheralId":peripheral.identifier.uuidString,"service":characteristic.service?.uuid.uuidString ?? "","characteristic":characteristic.uuid.uuidString,"packet":data.base64EncodedString(),"receivedAt":ISO8601DateFormatter().string(from:Date())]) }
    }
    completeIfReady(peripheral.identifier)
  }
  private func completeIfReady(_ id:UUID){ guard let session=sessions[id],session.pendingServiceDiscoveries==0,session.completedCharacteristics.isSuperset(of:session.expectedCharacteristics) else{return}; finish(id,error:nil) }
  private func finish(_ id:UUID,error:FlutterError?){ guard let session=sessions.removeValue(forKey:id),!session.completed else{return};session.completed=true;session.timeout?.cancel();if let error=error{session.result(error)}else{session.result(session.packets)} }
  private func describe(_ p:CBPeripheral)->[String:Any]{["id":p.identifier.uuidString,"name":p.name ?? "Fitness device","manufacturer":"unknown","firmwareVersion":"unknown","profiles":Array(advertisedProfiles[p.identifier] ?? [])]}
}
