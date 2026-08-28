import Flutter
import HealthKit
import UIKit

/// Production HealthKit bridge. Core correctness is covered by contract tests;
/// device certification remains an external release gate because HealthKit is
/// unavailable in a host-only Flutter test process.
final class BILGlobalHealthBridge: NSObject, FlutterPlugin {
  private let store: HKHealthStore
  private let channelName: String

  init(store: HKHealthStore = HKHealthStore(), channelName: String = "bil/apple_health") {
    self.store = store
    self.channelName = channelName
    super.init()
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = BILGlobalHealthBridge()
    let channel = FlutterMethodChannel(name: instance.channelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
#if DEBUG
    // Cloud-simulator evidence hook. It is compiled out of Release builds and
    // invokes the same production authorization path and reviewed read scope.
    if ProcessInfo.processInfo.arguments.contains("--bil-healthkit-capture") {
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        instance.requestAuthorization(
          arguments: ["types": Self.supportedTypeNames, "write": false],
          result: { _ in }
        )
      }
    }
#endif
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "availability":
      result(["available": HKHealthStore.isHealthDataAvailable(), "platform": "healthkit"])
    case "permissions":
      result(permissionSnapshot(arguments: call.arguments))
    case "requestPermissions":
      requestAuthorization(arguments: call.arguments, result: result)
    case "revokeAccess":
      // HealthKit access is withdrawn by the user in system Settings.
      result(["revoked": false, "requiresSystemSettings": true, "platform": "healthkit"])
    case "openSettings":
      guard let url = URL(string: UIApplication.openSettingsURLString) else {
        result(FlutterError(code: "settings_unavailable", message: nil, details: nil)); return
      }
      UIApplication.shared.open(url, options: [:]) { opened in
        result(opened ? nil : FlutterError(code: "settings_unavailable", message: nil, details: nil))
      }
    case "readChanges":
      readChanges(arguments: call.arguments, result: result)
    case "write":
      write(arguments: call.arguments, result: result)
    case "delete":
      delete(arguments: call.arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func permissionSnapshot(arguments: Any?) -> [String: Bool] {
    let args = arguments as? [String: Any]
    let requested = (args?["types"] as? [String]) ?? Self.supportedTypeNames
    var output: [String: Bool] = [:]
    for name in requested {
      guard let type = sampleType(name) else { output[name] = false; continue }
      output[name] = store.authorizationStatus(for: type) != .sharingDenied
    }
    return output
  }

  private func requestAuthorization(arguments: Any?, result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(error("unavailable", "HealthKit is unavailable on this device.")); return
    }
    let args = arguments as? [String: Any]
    let names = Set((args?["types"] as? [String]) ?? Self.supportedTypeNames)
    let writeRequested = (args?["write"] as? Bool) == true
    let readTypes = Set(names.compactMap(sampleType))
    let writeTypes: Set<HKSampleType> = writeRequested ? readTypes.filter(canWrite) : []
    store.requestAuthorization(toShare: writeTypes, read: readTypes) { success, failure in
      DispatchQueue.main.async {
        if let failure { result(self.error("authorization_failed", failure.localizedDescription)) }
        else if !success { result(self.error("authorization_incomplete", "Health authorization did not complete.")) }
        else { result(["requestCompleted": true, "readStatus": "indeterminate"]) }
      }
    }
  }

  private func readChanges(arguments: Any?, result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(error("unavailable", "HealthKit is unavailable on this device.")); return
    }
    let args = arguments as? [String: Any]
    let names = (args?["types"] as? [String]) ?? Self.supportedTypeNames
    let asOf = ISO8601DateFormatter().date(from: args?["asOf"] as? String ?? "") ?? Date()
    let anchors = decodeAnchors(args?["anchor"] as? String)
    let group = DispatchGroup()
    let lock = NSLock()
    var records: [[String: Any]] = []
    var deleted: [String] = []
    var nextAnchors = anchors
    var firstError: Error?

    for name in names {
      guard let type = sampleType(name) else { continue }
      group.enter()
      let predicate = HKQuery.predicateForSamples(withStart: nil, end: asOf, options: [])
      let query = HKAnchoredObjectQuery(type: type, predicate: predicate, anchor: anchors[name], limit: HKObjectQueryNoLimit) {
        [weak self] _, samples, deletedObjects, newAnchor, queryError in
        defer { group.leave() }
        guard let self else { return }
        lock.lock(); defer { lock.unlock() }
        if let queryError { firstError = firstError ?? queryError; return }
        records.append(contentsOf: (samples ?? []).compactMap { self.serialize(sample: $0, logicalType: name) })
        deleted.append(contentsOf: (deletedObjects ?? []).map { $0.uuid.uuidString })
        if let newAnchor { nextAnchors[name] = newAnchor }
      }
      store.execute(query)
    }

    group.notify(queue: .main) {
      if let firstError { result(self.error("query_failed", firstError.localizedDescription)); return }
      result([
        "records": records,
        "deletedIds": deleted,
        "nextAnchor": self.encodeAnchors(nextAnchors),
        "hasMore": false,
      ])
    }
  }

  private func write(arguments: Any?, result: @escaping FlutterResult) {
    let args = arguments as? [String: Any]
    let rows = (args?["signals"] as? [[String: Any]]) ?? []
    var samples: [HKSample] = []
    do {
      for row in rows { if let sample = try makeSample(row) { samples.append(sample) } }
    } catch { result(self.error("invalid_write_payload", error.localizedDescription)); return }
    guard !samples.isEmpty else { result(["written": 0]); return }
    store.save(samples) { success, failure in
      DispatchQueue.main.async {
        if let failure { result(self.error("write_failed", failure.localizedDescription)) }
        else { result(["written": success ? samples.count : 0]) }
      }
    }
  }

  private func delete(arguments: Any?, result: @escaping FlutterResult) {
    let ids = Set(((arguments as? [String: Any])?["recordIds"] as? [String] ?? []).compactMap(UUID.init(uuidString:)))
    guard !ids.isEmpty else { result(["deleted": 0]); return }
    let group = DispatchGroup(); let lock = NSLock(); var deletedCount = 0; var firstError: Error?
    for name in Self.supportedTypeNames {
      guard let type = sampleType(name) else { continue }
      group.enter()
      let query = HKSampleQuery(sampleType: type, predicate: HKQuery.predicateForObjects(with: ids), limit: HKObjectQueryNoLimit, sortDescriptors: nil) {
        [weak self] _, samples, queryError in
        guard let self else { group.leave(); return }
        if let queryError { lock.lock(); firstError = firstError ?? queryError; lock.unlock(); group.leave(); return }
        self.store.delete(samples ?? []) { success, deleteError in
          lock.lock()
          if let deleteError { firstError = firstError ?? deleteError }
          else if success { deletedCount += samples?.count ?? 0 }
          lock.unlock(); group.leave()
        }
      }
      store.execute(query)
    }
    group.notify(queue: .main) {
      if let firstError { result(self.error("delete_failed", firstError.localizedDescription)) }
      else { result(["deleted": deletedCount]) }
    }
  }

  private func serialize(sample: HKSample, logicalType: String) -> [String: Any]? {
    let source = sample.sourceRevision.source
    var value = 1.0; var unit = "count"
    if let quantity = sample as? HKQuantitySample, let preferred = preferredUnit(logicalType) {
      value = quantity.quantity.doubleValue(for: preferred); unit = unitName(logicalType)
    } else if let workout = sample as? HKWorkout {
      value = workout.duration; unit = "s"
    } else if sample is HKCategorySample, logicalType == "sleep" {
      value = sample.endDate.timeIntervalSince(sample.startDate) / 3600.0
      unit = "h"
    }
    var attributes: [String: Any] = [:]
    if let sleep = sample as? HKCategorySample, logicalType == "sleep" {
      attributes["sleepStage"] = sleepStage(sleep.value)
      attributes["endedAt"] = ISO8601DateFormatter().string(from: sleep.endDate)
    }
    return [
      "id": sample.uuid.uuidString,
      "type": logicalType,
      "value": value,
      "unit": unit,
      "observedAt": ISO8601DateFormatter().string(from: sample.startDate),
      "sourceId": source.bundleIdentifier,
      "deviceId": sample.device?.name as Any,
      "confidence": 1.0,
      "timeZoneId": sample.metadata?[HKMetadataKeyTimeZone] as? String ?? TimeZone.current.identifier,
      "deleted": false,
      "attributes": attributes,
    ]
  }

  private func makeSample(_ row: [String: Any]) throws -> HKSample? {
    guard let name = row["key"] as? String, let type = sampleType(name), canWrite(type),
          let value = row["canonicalValue"] as? NSNumber, let unit = preferredUnit(name) else { return nil }
    let observedAt = ISO8601DateFormatter().date(from: row["observedAt"] as? String ?? "") ?? Date()
    guard let quantityType = type as? HKQuantityType else { return nil }
    return HKQuantitySample(type: quantityType, quantity: HKQuantity(unit: unit, doubleValue: value.doubleValue), start: observedAt, end: observedAt)
  }

  private func sampleType(_ name: String) -> HKSampleType? {
    switch name {
    case "steps": return HKObjectType.quantityType(forIdentifier: .stepCount)
    case "distance": return HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
    case "activeEnergy": return HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
    case "workout": return HKObjectType.workoutType()
    case "sleep": return HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
    case "weight": return HKObjectType.quantityType(forIdentifier: .bodyMass)
    case "bodyFat": return HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)
    case "leanMass": return HKObjectType.quantityType(forIdentifier: .leanBodyMass)
    case "heartRate": return HKObjectType.quantityType(forIdentifier: .heartRate)
    case "restingHeartRate": return HKObjectType.quantityType(forIdentifier: .restingHeartRate)
    case "hrv": return HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
    case "water": return HKObjectType.quantityType(forIdentifier: .dietaryWater)
    case "nutrition": return HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)
    case "nutritionProtein": return HKObjectType.quantityType(forIdentifier: .dietaryProtein)
    case "nutritionCarbohydrates": return HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)
    case "nutritionFat": return HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)
    case "nutritionFiber": return HKObjectType.quantityType(forIdentifier: .dietaryFiber)
    case "nutritionSugar": return HKObjectType.quantityType(forIdentifier: .dietarySugar)
    case "nutritionSodium": return HKObjectType.quantityType(forIdentifier: .dietarySodium)
    case "nutritionPotassium": return HKObjectType.quantityType(forIdentifier: .dietaryPotassium)
    default: return nil
    }
  }

  private func preferredUnit(_ name: String) -> HKUnit? {
    switch name {
    case "steps": return .count()
    case "distance": return .meter()
    case "activeEnergy", "nutrition": return .kilocalorie()
    case "nutritionProtein", "nutritionCarbohydrates", "nutritionFat", "nutritionFiber", "nutritionSugar": return .gram()
    case "nutritionSodium", "nutritionPotassium": return .gramUnit(with: .milli)
    case "weight", "leanMass": return .gramUnit(with: .kilo)
    case "bodyFat": return .percent()
    case "heartRate", "restingHeartRate": return HKUnit.count().unitDivided(by: .minute())
    case "hrv": return .secondUnit(with: .milli)
    case "water": return .literUnit(with: .milli)
    default: return nil
    }
  }

  private func unitName(_ name: String) -> String {
    switch name {
    case "distance": return "m"
    case "activeEnergy", "nutrition": return "kcal"
    case "nutritionProtein", "nutritionCarbohydrates", "nutritionFat", "nutritionFiber", "nutritionSugar": return "g"
    case "nutritionSodium", "nutritionPotassium": return "mg"
    case "weight", "leanMass": return "kg"
    case "bodyFat": return "%"
    case "heartRate", "restingHeartRate": return "count/min"
    case "hrv": return "ms"
    case "water": return "mL"
    default: return "count"
    }
  }

  private func canWrite(_ type: HKSampleType) -> Bool {
    type == HKObjectType.quantityType(forIdentifier: .bodyMass)
  }

  private func sleepStage(_ rawValue: Int) -> String {
    if #available(iOS 16.0, *) {
      switch rawValue {
      case HKCategoryValueSleepAnalysis.awake.rawValue: return "awake"
      case HKCategoryValueSleepAnalysis.asleepREM.rawValue: return "rem"
      case HKCategoryValueSleepAnalysis.asleepCore.rawValue: return "core"
      case HKCategoryValueSleepAnalysis.asleepDeep.rawValue: return "deep"
      case HKCategoryValueSleepAnalysis.inBed.rawValue: return "inBed"
      case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue: return "asleepUnspecified"
      default: return "unknown"
      }
    }
    return rawValue == HKCategoryValueSleepAnalysis.inBed.rawValue ? "inBed" : "asleepUnspecified"
  }

  private func encodeAnchors(_ anchors: [String: HKQueryAnchor]) -> String? {
    var encoded: [String: String] = [:]
    for (name, anchor) in anchors {
      if let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) { encoded[name] = data.base64EncodedString() }
    }
    guard let data = try? JSONSerialization.data(withJSONObject: encoded) else { return nil }
    return data.base64EncodedString()
  }

  private func decodeAnchors(_ raw: String?) -> [String: HKQueryAnchor] {
    guard let raw, let data = Data(base64Encoded: raw),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else { return [:] }
    var output: [String: HKQueryAnchor] = [:]
    for (name, value) in json {
      guard let archive = Data(base64Encoded: value),
            let anchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: archive) else { continue }
      output[name] = anchor
    }
    return output
  }

  private func error(_ code: String, _ message: String) -> FlutterError { FlutterError(code: code, message: message, details: ["bridge": channelName]) }

  static let supportedTypeNames = [
    "steps", "distance", "activeEnergy", "workout", "sleep", "weight",
    "bodyFat", "leanMass", "heartRate", "restingHeartRate", "hrv",
    "water", "nutrition", "nutritionProtein",
    "nutritionCarbohydrates", "nutritionFat", "nutritionFiber",
    "nutritionSugar", "nutritionSodium", "nutritionPotassium"
  ]
}
