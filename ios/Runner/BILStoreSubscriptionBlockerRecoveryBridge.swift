import Flutter
import Foundation
import StoreKit

struct BILStoreSubscriptionInventory {
  let currentEntitlementCount: Int
  let unfinishedCount: Int

  var payload: [String: Int] {
    ["scopeVersion": 1,
     "currentEntitlementCount": currentEntitlementCount,
     "unfinishedCount": unfinishedCount]
  }
}

enum BILStoreSubscriptionInventoryError: Error {
  case unsupported, unverified, resourceLimit
}

/// Negative read-only evidence only. This bridge exports counts, never a
/// transaction identifier, receipt, JWS, entitlement grant or customer data.
final class BILStoreSubscriptionBlockerRecoveryBridge {
  typealias Reader = () async throws -> BILStoreSubscriptionInventory
  private let channel: FlutterMethodChannel
  private let reader: Reader
  private var requestID: UUID?
  private var readTask: Task<Void, Never>?
  private var deadline: DispatchWorkItem?

  init(messenger: FlutterBinaryMessenger, reader: Reader? = nil) {
    self.reader = reader ?? Self.readStoreKitInventory
    channel = FlutterMethodChannel(
      name: "bil/store_subscription_blocker_recovery",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "readInventory" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard call.arguments == nil, let self else {
        result(FlutterError(code: "store_inventory_unavailable", message: nil, details: nil))
        return
      }
      self.read(result)
    }
  }

  deinit {
    deadline?.cancel()
    readTask?.cancel()
  }

  private func read(_ result: @escaping FlutterResult) {
    guard #available(iOS 15.0, *) else {
      result(FlutterError(code: "store_inventory_unsupported", message: nil, details: nil))
      return
    }
    guard requestID == nil else {
      result(FlutterError(code: "store_inventory_busy", message: nil, details: nil))
      return
    }
    let id = UUID()
    requestID = id
    let timeout = DispatchWorkItem { [weak self] in
      guard let self, self.requestID == id else { return }
      self.readTask?.cancel()
      self.complete(id, result: result, value: FlutterError(
        code: "store_inventory_timeout", message: nil, details: nil
      ))
    }
    deadline = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 7, execute: timeout)
    let reader = self.reader
    readTask = Task { [weak self] in
      do {
        let inventory = try await reader()
        try Task.checkCancellation()
        guard inventory.currentEntitlementCount >= 0,
              inventory.currentEntitlementCount <= 10000,
              inventory.unfinishedCount >= 0,
              inventory.unfinishedCount <= 10000 else {
          throw BILStoreSubscriptionInventoryError.resourceLimit
        }
        await MainActor.run {
          self?.complete(id, result: result, value: inventory.payload)
        }
      } catch {
        // No exception descriptions, transactions or partial counts cross the
        // channel. A failed/cancelled/unverified enumeration is never empty.
        await MainActor.run {
          self?.complete(id, result: result, value: FlutterError(
            code: "store_inventory_unavailable", message: nil, details: nil
          ))
        }
      }
    }
  }

  private func complete(_ id: UUID, result: FlutterResult, value: Any) {
    guard requestID == id else { return }
    requestID = nil
    deadline?.cancel()
    deadline = nil
    readTask = nil
    result(value)
  }

  private static func readStoreKitInventory() async throws -> BILStoreSubscriptionInventory {
    guard #available(iOS 15.0, *) else {
      throw BILStoreSubscriptionInventoryError.unsupported
    }
    var current = 0
    for await entry in StoreKit.Transaction.currentEntitlements {
      try Task.checkCancellation()
      guard case .verified = entry else {
        throw BILStoreSubscriptionInventoryError.unverified
      }
      current += 1
      guard current <= 10000 else { throw BILStoreSubscriptionInventoryError.resourceLimit }
    }
    var unfinished = 0
    for await entry in StoreKit.Transaction.unfinished {
      try Task.checkCancellation()
      guard case .verified = entry else {
        throw BILStoreSubscriptionInventoryError.unverified
      }
      unfinished += 1
      guard unfinished <= 10000 else { throw BILStoreSubscriptionInventoryError.resourceLimit }
    }
    try Task.checkCancellation()
    return BILStoreSubscriptionInventory(
      currentEntitlementCount: current,
      unfinishedCount: unfinished
    )
  }
}
