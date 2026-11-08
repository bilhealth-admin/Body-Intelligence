import Flutter
import UIKit
import XCTest
import SwiftUI
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
  @MainActor
  func testSplashCapsuleReducedMotionKeepsIdenticalPixels() throws {
    guard #available(iOS 16.0, *) else { throw XCTSkip("ImageRenderer requires iOS 16") }
    let first = try renderCapsule(phase: 0, reduced: true)
    let last = try renderCapsule(phase: 1, reduced: true)
    XCTAssertEqual(first.width, 24)
    XCTAssertEqual(first.height, 7)
    XCTAssertEqual(try capsulePixels(first), try capsulePixels(last))
    let moving = try renderCapsule(phase: 0.72, reduced: false)
    XCTAssertNotEqual(try capsulePixels(first), try capsulePixels(moving))
  }

  @MainActor
  func testSplashCapsuleMotionChangesPaintWithoutChangingFootprint() throws {
    guard #available(iOS 16.0, *) else { throw XCTSkip("ImageRenderer requires iOS 16") }
    let first = try renderCapsule(phase: 0, reduced: false)
    let last = try renderCapsule(phase: 1, reduced: false)
    XCTAssertEqual(first.width, 24)
    XCTAssertEqual(first.height, 7)
    XCTAssertEqual(last.width, first.width)
    XCTAssertEqual(last.height, first.height)
    XCTAssertNotEqual(try capsulePixels(first), try capsulePixels(last))
    XCTAssertEqual(BILNativeSplashCapsulePaint.emphasized(0), 0)
    XCTAssertEqual(BILNativeSplashCapsulePaint.emphasized(1), 1)
    XCTAssertEqual(BILNativeSplashCapsulePaint.emphasized(0.166666), 0.4, accuracy: 0.000001)
    XCTAssertEqual(BILNativeSplashCapsulePaint.emphasized(.nan), 0)
    XCTAssertEqual(BILNativeSplashCapsulePaint.emphasized(-.infinity), 0)
    XCTAssertEqual(BILNativeSplashCapsulePaint.emphasized(.infinity), 1)
    let invalid = try renderCapsule(phase: .nan, reduced: false)
    let negativeInfinity = try renderCapsule(phase: -.infinity, reduced: false)
    let positiveInfinity = try renderCapsule(phase: .infinity, reduced: false)
    XCTAssertEqual(try capsulePixels(invalid), try capsulePixels(first))
    XCTAssertEqual(try capsulePixels(negativeInfinity), try capsulePixels(first))
    XCTAssertEqual(try capsulePixels(positiveInfinity), try capsulePixels(last))
  }

  @MainActor
  func testSplashCapsulePreservesPhysicalDirectionAndAccessibleColors() throws {
    guard #available(iOS 16.0, *) else { throw XCTSkip("ImageRenderer requires iOS 16") }
    let light = try renderCapsule(phase: 1, reduced: false)
    let dark = try renderCapsule(phase: 1, reduced: false, scheme: .dark)
    let rtl = try renderCapsule(phase: 1, reduced: false, direction: .rightToLeft)
    let highLight = try renderCapsule(phase: 1, reduced: false, contrast: .increased)
    let highDark = try renderCapsule(phase: 1, reduced: false, scheme: .dark, contrast: .increased)
    XCTAssertEqual(try capsulePixels(light), try capsulePixels(rtl))
    XCTAssertNotEqual(try capsulePixels(light), try capsulePixels(dark))
    for image in [light, dark, rtl, highLight, highDark] {
      XCTAssertEqual(image.width, 24)
      XCTAssertEqual(image.height, 7)
    }
    // Canonical RGBA center pixels verify the actual image, not just constants.
    let center = (3 * 24 + 12) * 4
    let normalLight = try capsulePixels(light)
    let normalDark = try capsulePixels(dark)
    let black = try capsulePixels(highLight)
    let white = try capsulePixels(highDark)
    let lightAlpha = Double(normalLight[center + 3])
    let darkAlpha = Double(normalDark[center + 3])
    XCTAssertGreaterThan(lightAlpha, 0)
    XCTAssertGreaterThan(darkAlpha, 0)
    XCTAssertEqual(Double(normalLight[center]) * 255 / lightAlpha, 16, accuracy: 2)
    XCTAssertEqual(Double(normalLight[center + 1]) * 255 / lightAlpha, 37, accuracy: 2)
    XCTAssertEqual(Double(normalLight[center + 2]) * 255 / lightAlpha, 74, accuracy: 2)
    XCTAssertEqual(Double(normalDark[center]) * 255 / darkAlpha, 140, accuracy: 2)
    XCTAssertEqual(Double(normalDark[center + 1]) * 255 / darkAlpha, 207, accuracy: 2)
    XCTAssertEqual(Double(normalDark[center + 2]) * 255 / darkAlpha, 255, accuracy: 2)
    XCTAssertGreaterThan(normalLight[center + 2], normalLight[center])
    XCTAssertGreaterThan(normalDark[center + 2], normalDark[center])
    XCTAssertEqual(black[center], 0)
    XCTAssertEqual(black[center + 1], 0)
    XCTAssertEqual(black[center + 2], 0)
    XCTAssertGreaterThan(white[center + 3], 0)
    XCTAssertEqual(white[center], white[center + 3])
    XCTAssertEqual(white[center + 1], white[center + 3])
    XCTAssertEqual(white[center + 2], white[center + 3])
  }

  @available(iOS 16.0, *)
  @MainActor
  private func renderCapsule(
    phase: Double, reduced: Bool, scheme: ColorScheme = .light,
    direction: LayoutDirection = .leftToRight, contrast: ColorSchemeContrast = .standard
  ) throws -> CGImage {
    let renderer = ImageRenderer(content:
      BILNativeSplashCapsulePaint(progress: phase, reducedMotion: reduced)
        .environment(\.colorScheme, scheme)
        .environment(\.colorSchemeContrast, contrast)
        .environment(\.layoutDirection, direction)
    )
    renderer.scale = 1
    renderer.isOpaque = false
    let image = try XCTUnwrap(renderer.cgImage, "Native capsule must rasterize a real image")
    let attachment = XCTAttachment(image: UIImage(cgImage: image))
    attachment.name = "capsule-phase\(phase)-reduced\(reduced)-\(scheme)-\(direction)-\(contrast)"
    attachment.lifetime = .keepAlways
    add(attachment)
    return image
  }

  private func capsulePixels(_ image: CGImage) throws -> [UInt8] {
    var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    try pixels.withUnsafeMutableBytes { storage in
      let context = try XCTUnwrap(CGContext(
        data: storage.baseAddress, width: image.width, height: image.height,
        bitsPerComponent: 8, bytesPerRow: image.width * 4, space: colorSpace,
        bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
      ))
      context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
    }
    return pixels
  }

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
