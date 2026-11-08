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
    // Snapshot the actual SwiftUI view through UIKit's real trait bridge.
    // A non-key fixture uses layer rendering, with a completed appearance
    // lifecycle, rather than drawHierarchy before SwiftUI has painted.
    let bounds = CGRect(x: 0, y: 0, width: 24, height: 7)
    let requestedContrast: UIAccessibilityContrast = contrast == .increased ? .high : .normal
    let requestedStyle: UIUserInterfaceStyle = scheme == .dark ? .dark : .light
    let hosting = UIHostingController(rootView:
      BILNativeSplashCapsulePaint(progress: phase, reducedMotion: reduced)
        .environment(\.colorScheme, scheme)
        .environment(\.layoutDirection, direction)
        .ignoresSafeArea()
    )
    if #available(iOS 16.4, *) { hosting.safeAreaRegions = [] }
    let container = UIViewController()
    container.view.backgroundColor = .clear
    container.view.frame = bounds
    container.addChild(hosting)
    container.view.addSubview(hosting.view)
    hosting.didMove(toParent: container)
    hosting.view.frame = bounds
    hosting.view.backgroundColor = .clear
    hosting.view.isOpaque = false

    if #available(iOS 17.0, *) {
      hosting.traitOverrides.accessibilityContrast = requestedContrast
      hosting.traitOverrides.userInterfaceStyle = requestedStyle
      hosting.traitOverrides.displayScale = 1
    } else {
      container.setOverrideTraitCollection(UITraitCollection(traitsFrom: [
        UITraitCollection(accessibilityContrast: requestedContrast),
        UITraitCollection(userInterfaceStyle: requestedStyle),
        UITraitCollection(displayScale: 1)
      ]), forChild: hosting)
    }

    // This isolated non-key window never replaces the application's root/key
    // window, and is disposed only after both appearance transitions finish.
    let window = UIWindow(frame: bounds)
    window.backgroundColor = .clear
    window.isHidden = false
    window.rootViewController = container
    container.beginAppearanceTransition(true, animated: false)
    container.endAppearanceTransition()
    defer {
      container.beginAppearanceTransition(false, animated: false)
      hosting.willMove(toParent: nil)
      hosting.view.removeFromSuperview()
      hosting.removeFromParent()
      container.endAppearanceTransition()
      window.rootViewController = nil
      window.isHidden = true
    }
    if #available(iOS 17.0, *) { hosting.updateTraitsIfNeeded() }
    container.view.setNeedsLayout()
    container.view.layoutIfNeeded()
    hosting.view.setNeedsLayout()
    hosting.view.layoutIfNeeded()

    // Yield the main run loop so UIKit/SwiftUI can commit their first frame.
    // This is test-only readiness; no application timeout or state changes.
    let ready = expectation(description: "Native capsule initial display transaction")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { ready.fulfill() }
    wait(for: [ready], timeout: 2)
    container.view.layoutIfNeeded()
    hosting.view.layoutIfNeeded()
    hosting.view.layer.displayIfNeeded()
    XCTAssertEqual(hosting.traitCollection.accessibilityContrast, requestedContrast)
    XCTAssertEqual(hosting.view.traitCollection.accessibilityContrast, requestedContrast)
    XCTAssertEqual(hosting.view.bounds.size, bounds.size)

    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = false
    format.preferredRange = .standard
    let rendered = UIGraphicsImageRenderer(size: bounds.size, format: format).image { context in
      hosting.view.layer.render(in: context.cgContext)
    }
    let image = try XCTUnwrap(rendered.cgImage, "Native capsule must rasterize a real image")
    let pixels = try capsulePixels(image)
    XCTAssertTrue(stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 },
      "Native capsule snapshot must contain actual painted pixels")
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
