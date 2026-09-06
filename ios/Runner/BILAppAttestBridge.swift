import DeviceCheck
import Flutter
import Foundation
import Security

enum BILAppAttestKeyStoreError: Error {
  case invalidStoredKeyId
  case keychain(OSStatus)
}

protocol BILAppAttestKeyValueStore {
  func read(accountId: String) throws -> String?
  func write(keyId: String, accountId: String) throws
  func delete(accountId: String) throws
}

/// Stores only App Attest's opaque key identifier. Apple keeps the private key
/// in the Secure Enclave; the identifier must remain local to this device so it
/// cannot be restored onto hardware that does not own the corresponding key.
struct BILAppAttestKeychainStore: BILAppAttestKeyValueStore {
  private let service: String

  init(
    service: String = "com.bilhealth.bodyintelligencelog.app-attest-key-id.v1"
  ) {
    self.service = service
  }

  func read(accountId: String) throws -> String? {
    var query = baseQuery(accountId: accountId)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound {
      return nil
    }
    guard status == errSecSuccess else {
      throw BILAppAttestKeyStoreError.keychain(status)
    }
    guard let data = item as? Data,
          let keyId = String(data: data, encoding: .utf8),
          !keyId.isEmpty,
          keyId.utf8.count <= 256 else {
      throw BILAppAttestKeyStoreError.invalidStoredKeyId
    }
    return keyId
  }

  func write(keyId: String, accountId: String) throws {
    guard !keyId.isEmpty,
          keyId.utf8.count <= 256,
          let data = keyId.data(using: .utf8) else {
      throw BILAppAttestKeyStoreError.invalidStoredKeyId
    }

    let query = baseQuery(accountId: accountId)
    let update: [String: Any] = [kSecValueData as String: data]
    let updateStatus = SecItemUpdate(
      query as CFDictionary,
      update as CFDictionary
    )
    if updateStatus == errSecSuccess {
      return
    }
    guard updateStatus == errSecItemNotFound else {
      throw BILAppAttestKeyStoreError.keychain(updateStatus)
    }

    var insertion = query
    insertion[kSecValueData as String] = data
    insertion[kSecAttrAccessible as String] =
      kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let insertionStatus = SecItemAdd(insertion as CFDictionary, nil)
    if insertionStatus == errSecDuplicateItem {
      let raceStatus = SecItemUpdate(
        query as CFDictionary,
        update as CFDictionary
      )
      guard raceStatus == errSecSuccess else {
        throw BILAppAttestKeyStoreError.keychain(raceStatus)
      }
      return
    }
    guard insertionStatus == errSecSuccess else {
      throw BILAppAttestKeyStoreError.keychain(insertionStatus)
    }
  }

  func delete(accountId: String) throws {
    let status = SecItemDelete(baseQuery(accountId: accountId) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw BILAppAttestKeyStoreError.keychain(status)
    }
  }

  private func baseQuery(accountId: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: accountId,
      kSecAttrSynchronizable as String: false,
    ]
  }
}

/// Migrates the prior app-owned UserDefaults map one account at a time. The
/// legacy entry is removed only after a successful Keychain write, so an
/// update never strands an already-generated App Attest key identifier.
final class BILAppAttestKeyStore {
  private let keychain: BILAppAttestKeyValueStore
  private let defaults: UserDefaults
  private let legacyDefaultsKey: String

  init(
    keychain: BILAppAttestKeyValueStore = BILAppAttestKeychainStore(),
    defaults: UserDefaults = .standard,
    legacyDefaultsKey: String = "bil.app_attest.key_ids.v1"
  ) {
    self.keychain = keychain
    self.defaults = defaults
    self.legacyDefaultsKey = legacyDefaultsKey
  }

  func keyId(for accountId: String) throws -> String? {
    if let keyId = try keychain.read(accountId: accountId) {
      // Keychain is authoritative after migration. A stale, different legacy
      // value must not be resurrected after the current key is discarded.
      removeLegacyKeyId(for: accountId)
      return keyId
    }
    guard let legacyKeyId = validLegacyKeyId(for: accountId) else {
      return nil
    }

    try keychain.write(keyId: legacyKeyId, accountId: accountId)
    removeLegacyKeyId(for: accountId)
    return legacyKeyId
  }

  func save(keyId: String, for accountId: String) throws {
    try keychain.write(keyId: keyId, accountId: accountId)
    removeLegacyKeyId(for: accountId)
  }

  func remove(keyId expectedKeyId: String, for accountId: String) throws {
    guard try keyId(for: accountId) == expectedKeyId else {
      return
    }
    try keychain.delete(accountId: accountId)
  }

  private func validLegacyKeyId(for accountId: String) -> String? {
    guard let value = defaults.dictionary(forKey: legacyDefaultsKey)?[accountId] as? String,
      !value.isEmpty,
      value.utf8.count <= 256 else {
      return nil
    }
    return value
  }

  private func removeLegacyKeyId(for accountId: String) {
    guard var values = defaults.dictionary(forKey: legacyDefaultsKey) else {
      return
    }
    values.removeValue(forKey: accountId)
    if values.isEmpty {
      defaults.removeObject(forKey: legacyDefaultsKey)
    } else {
      defaults.set(values, forKey: legacyDefaultsKey)
    }
  }
}

/// Opaque Flutter bridge for App Attest. Verification never occurs on-device;
/// the bridge only owns Apple's per-install private-key handle and returns the
/// attestation/assertion bytes to the authenticated BIL backend.
final class BILAppAttestBridge {
  private let channel: FlutterMethodChannel
  private let service = DCAppAttestService.shared
  private let keyStore: BILAppAttestKeyStore

  init(
    messenger: FlutterBinaryMessenger,
    keyStore: BILAppAttestKeyStore = BILAppAttestKeyStore()
  ) {
    self.channel = FlutterMethodChannel(
      name: "bil/app_attest",
      binaryMessenger: messenger
    )
    self.keyStore = keyStore
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(service.isSupported)
    case "keyId":
      guard let accountId = accountId(from: call) else {
        result(error("invalid_account_id"))
        return
      }
      do {
        result(try keyStore.keyId(for: accountId))
      } catch {
        result(keyStoreError(error))
      }
    case "generateKey":
      guard service.isSupported else {
        result(error("app_attest_not_supported"))
        return
      }
      guard let accountId = accountId(from: call) else {
        result(error("invalid_account_id"))
        return
      }
      do {
        if let existing = try keyStore.keyId(for: accountId) {
          result(existing)
          return
        }
      } catch {
        result(keyStoreError(error))
        return
      }
      service.generateKey { [weak self] keyId, generationError in
        DispatchQueue.main.async {
          guard let self else {
            result(FlutterError(code: "app_attest_bridge_released", message: nil, details: nil))
            return
          }
          if let generationError {
            result(self.flutterError("app_attest_key_failed", generationError))
            return
          }
          guard let keyId, !keyId.isEmpty else {
            result(self.error("app_attest_key_empty"))
            return
          }
          do {
            // A Supabase account gets its own App Attest key on this device.
            try self.keyStore.save(keyId: keyId, for: accountId)
            result(keyId)
          } catch {
            result(self.keyStoreError(error))
          }
        }
      }
    case "attestKey":
      guard service.isSupported else {
        result(error("app_attest_not_supported"))
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            let keyId = boundedKeyId(arguments["keyId"]),
            let clientDataHash = hashData(arguments["clientDataHash"]) else {
        result(error("invalid_app_attest_arguments"))
        return
      }
      service.attestKey(keyId, clientDataHash: clientDataHash) { [weak self] object, attestError in
        DispatchQueue.main.async {
          guard let self else {
            result(FlutterError(code: "app_attest_bridge_released", message: nil, details: nil))
            return
          }
          if let attestError {
            result(self.flutterError("app_attest_failed", attestError))
            return
          }
          guard let object, !object.isEmpty else {
            result(self.error("app_attest_object_empty"))
            return
          }
          result(object.base64EncodedString())
        }
      }
    case "generateAssertion":
      guard service.isSupported else {
        result(error("app_attest_not_supported"))
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            let keyId = boundedKeyId(arguments["keyId"]),
            let clientDataHash = hashData(arguments["clientDataHash"]) else {
        result(error("invalid_app_attest_arguments"))
        return
      }
      service.generateAssertion(keyId, clientDataHash: clientDataHash) { [weak self] assertion, assertionError in
        DispatchQueue.main.async {
          guard let self else {
            result(FlutterError(code: "app_attest_bridge_released", message: nil, details: nil))
            return
          }
          if let assertionError {
            result(self.flutterError("app_attest_assertion_failed", assertionError))
            return
          }
          guard let assertion, !assertion.isEmpty else {
            result(self.error("app_attest_assertion_empty"))
            return
          }
          result(assertion.base64EncodedString())
        }
      }
    case "discardKey":
      guard let accountId = accountId(from: call),
            let arguments = call.arguments as? [String: Any],
            let requestedKeyId = boundedKeyId(arguments["keyId"]) else {
        result(error("invalid_app_attest_arguments"))
        return
      }
      do {
        try keyStore.remove(keyId: requestedKeyId, for: accountId)
        result(nil)
      } catch {
        result(keyStoreError(error))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func accountId(from call: FlutterMethodCall) -> String? {
    guard let arguments = call.arguments as? [String: Any],
          let value = arguments["accountId"] as? String,
          UUID(uuidString: value) != nil else {
      return nil
    }
    return value.lowercased()
  }

  private func boundedKeyId(_ value: Any?) -> String? {
    guard let keyId = value as? String,
          !keyId.isEmpty,
          keyId.utf8.count <= 256 else {
      return nil
    }
    return keyId
  }

  private func hashData(_ value: Any?) -> Data? {
    guard let encoded = value as? String,
          encoded.utf8.count <= 64,
          let data = Data(base64Encoded: encoded),
          data.count == 32 else {
      return nil
    }
    return data
  }

  private func flutterError(_ code: String, _ source: Error) -> FlutterError {
    let nsError = source as NSError
    let retryable = nsError.domain == DCError.errorDomain &&
      nsError.code == DCError.Code.serverUnavailable.rawValue
    return FlutterError(
      code: code,
      message: nil,
      details: ["nativeCode": nsError.code, "retryable": retryable]
    )
  }

  private func keyStoreError(_ source: Error) -> FlutterError {
    let nativeCode: Int
    if case let BILAppAttestKeyStoreError.keychain(status) = source {
      nativeCode = Int(status)
    } else {
      nativeCode = -1
    }
    return FlutterError(
      code: "app_attest_key_store_failed",
      message: nil,
      details: ["nativeCode": nativeCode]
    )
  }

  private func error(_ code: String) -> FlutterError {
    FlutterError(code: code, message: nil, details: nil)
  }
}
