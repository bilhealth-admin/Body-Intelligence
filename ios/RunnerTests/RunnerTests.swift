import Flutter
import UIKit
import XCTest
@testable import Runner

private enum BILAppAttestKeyStoreTestError: Error {
  case forcedWriteFailure
}

private final class InMemoryAppAttestKeyValueStore: BILAppAttestKeyValueStore {
  var values: [String: String] = [:]
  var failWrites = false

  func read(accountId: String) throws -> String? {
    values[accountId]
  }

  func write(keyId: String, accountId: String) throws {
    if failWrites {
      throw BILAppAttestKeyStoreTestError.forcedWriteFailure
    }
    values[accountId] = keyId
  }

  func delete(accountId: String) throws {
    values.removeValue(forKey: accountId)
  }
}

class RunnerTests: XCTestCase {
  func testAppAttestKeyStoreKeepsAccountsIsolated() throws {
    try withIsolatedDefaults { defaults in
      let backend = InMemoryAppAttestKeyValueStore()
      let store = BILAppAttestKeyStore(
        keychain: backend,
        defaults: defaults
      )
      let firstAccount = "11111111-1111-1111-1111-111111111111"
      let secondAccount = "22222222-2222-2222-2222-222222222222"

      try store.save(keyId: "first-key", for: firstAccount)
      try store.save(keyId: "second-key", for: secondAccount)

      XCTAssertEqual(try store.keyId(for: firstAccount), "first-key")
      XCTAssertEqual(try store.keyId(for: secondAccount), "second-key")
    }
  }

  func testAppAttestKeyStoreMigratesLegacyAccountsOneAtATime() throws {
    try withIsolatedDefaults { defaults in
      let backend = InMemoryAppAttestKeyValueStore()
      let legacyKey = "bil.app_attest.key_ids.v1"
      let firstAccount = "11111111-1111-1111-1111-111111111111"
      let secondAccount = "22222222-2222-2222-2222-222222222222"
      defaults.set(
        [firstAccount: "first-key", secondAccount: "second-key"],
        forKey: legacyKey
      )
      let store = BILAppAttestKeyStore(
        keychain: backend,
        defaults: defaults,
        legacyDefaultsKey: legacyKey
      )

      XCTAssertEqual(try store.keyId(for: firstAccount), "first-key")
      XCTAssertEqual(backend.values[firstAccount], "first-key")
      XCTAssertNil(defaults.dictionary(forKey: legacyKey)?[firstAccount])
      XCTAssertEqual(
        defaults.dictionary(forKey: legacyKey)?[secondAccount] as? String,
        "second-key"
      )

      XCTAssertEqual(try store.keyId(for: secondAccount), "second-key")
      XCTAssertNil(defaults.object(forKey: legacyKey))
    }
  }

  func testAppAttestLegacyEntrySurvivesFailedKeychainMigration() throws {
    try withIsolatedDefaults { defaults in
      let backend = InMemoryAppAttestKeyValueStore()
      backend.failWrites = true
      let legacyKey = "bil.app_attest.key_ids.v1"
      let account = "11111111-1111-1111-1111-111111111111"
      defaults.set([account: "existing-key"], forKey: legacyKey)
      let store = BILAppAttestKeyStore(
        keychain: backend,
        defaults: defaults,
        legacyDefaultsKey: legacyKey
      )

      XCTAssertThrowsError(try store.keyId(for: account))
      XCTAssertEqual(
        defaults.dictionary(forKey: legacyKey)?[account] as? String,
        "existing-key"
      )
    }
  }

  func testAppAttestKeyStoreDeletesOnlyTheExpectedAccountKey() throws {
    try withIsolatedDefaults { defaults in
      let backend = InMemoryAppAttestKeyValueStore()
      let account = "11111111-1111-1111-1111-111111111111"
      backend.values[account] = "current-key"
      let store = BILAppAttestKeyStore(
        keychain: backend,
        defaults: defaults
      )

      try store.remove(keyId: "stale-key", for: account)
      XCTAssertEqual(backend.values[account], "current-key")

      try store.remove(keyId: "current-key", for: account)
      XCTAssertNil(backend.values[account])
    }
  }

  func testAppAttestDiscardCannotResurrectAnOlderLegacyKey() throws {
    try withIsolatedDefaults { defaults in
      let backend = InMemoryAppAttestKeyValueStore()
      let account = "11111111-1111-1111-1111-111111111111"
      let legacyKey = "bil.app_attest.key_ids.v1"
      backend.values[account] = "current-key"
      defaults.set([account: "obsolete-key"], forKey: legacyKey)
      let store = BILAppAttestKeyStore(keychain: backend, defaults: defaults)

      try store.remove(keyId: "current-key", for: account)

      XCTAssertNil(try store.keyId(for: account))
      XCTAssertNil(defaults.object(forKey: legacyKey))
    }
  }

  private func withIsolatedDefaults(
    _ body: (UserDefaults) throws -> Void
  ) throws {
    let suiteName = "bil.runner-tests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      XCTFail("Unable to create isolated UserDefaults suite")
      return
    }
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }
    try body(defaults)
  }
}
