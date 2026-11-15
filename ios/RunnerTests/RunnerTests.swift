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
  func testSplashCapsuleReducedMotionKeepsIdenticalPixels() async throws {
    guard #available(iOS 16.0, *) else { throw XCTSkip("ImageRenderer requires iOS 16") }
    let first = try await renderCapsule(phase: 0, reduced: true)
    let last = try await renderCapsule(phase: 1, reduced: true)
    XCTAssertEqual(first.width, 24)
    XCTAssertEqual(first.height, 7)
    XCTAssertEqual(try capsulePixels(first), try capsulePixels(last))
    let moving = try await renderCapsule(phase: 0.72, reduced: false)
    XCTAssertNotEqual(try capsulePixels(first), try capsulePixels(moving))
  }

  @MainActor
  func testSplashCapsuleMotionChangesPaintWithoutChangingFootprint() async throws {
    guard #available(iOS 16.0, *) else { throw XCTSkip("ImageRenderer requires iOS 16") }
    let first = try await renderCapsule(phase: 0, reduced: false)
    let last = try await renderCapsule(phase: 1, reduced: false)
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
    let invalid = try await renderCapsule(phase: .nan, reduced: false)
    let negativeInfinity = try await renderCapsule(phase: -.infinity, reduced: false)
    let positiveInfinity = try await renderCapsule(phase: .infinity, reduced: false)
    XCTAssertEqual(try capsulePixels(invalid), try capsulePixels(first))
    XCTAssertEqual(try capsulePixels(negativeInfinity), try capsulePixels(first))
    XCTAssertEqual(try capsulePixels(positiveInfinity), try capsulePixels(last))
  }

  @MainActor
  func testSplashCapsulePreservesPhysicalDirectionAndAccessibleColors() async throws {
    guard #available(iOS 16.0, *) else { throw XCTSkip("ImageRenderer requires iOS 16") }
    let light = try await renderCapsule(phase: 1, reduced: false)
    let dark = try await renderCapsule(phase: 1, reduced: false, scheme: .dark)
    let rtl = try await renderCapsule(phase: 1, reduced: false, direction: .rightToLeft)
    let highLight = try await renderCapsule(phase: 1, reduced: false, contrast: .increased)
    let highDark = try await renderCapsule(phase: 1, reduced: false, scheme: .dark, contrast: .increased)
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
  ) async throws -> CGImage {
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

    // Suspend this async fixture while the main queue takes another turn.
    // This bounded yield does not prove a completed display transaction;
    // actual pixels, dimensions and UIKit traits are asserted below.
    let ready = expectation(description: "Native capsule render fixture main-queue turn")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { ready.fulfill() }
    await fulfillment(of: [ready], timeout: 2)
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

  func testModernCallbackRequiresExactAssociatedHTTPSOrigin() {
    XCTAssertEqual(BILFacebookOAuthBridge.callbackMode, "legacy")
    XCTAssertTrue(callback("https://www.bilhealth.com/auth/callback?code=synthetic", https: true))
    for raw in [
      "https://www.bilhealth.com.evil.example/auth/callback?code=synthetic",
      "https://evil.example/auth/callback?code=synthetic",
      "https://user@www.bilhealth.com/auth/callback?code=synthetic",
      "https://www.bilhealth.com:8443/auth/callback?code=synthetic",
      "https://www.bilhealth.com/auth/reset-password?code=synthetic",
      "bil://auth-callback?code=synthetic"
    ] { XCTAssertFalse(callback(raw, https: true), raw) }
  }

  func testLegacyCallbackIsExactAndCannotUseGenericRoutes() {
    XCTAssertEqual(BILFacebookOAuthBridge.callbackMode, "legacy")
    XCTAssertTrue(callback("bil://auth-callback?code=synthetic", https: false))
    for raw in [
      "bil://auth/callback?code=synthetic", "bil://plans?code=synthetic",
      "bil://auth/reset-password?code=synthetic", "bil://user@auth/callback?code=synthetic",
      "bil://auth:123/callback?code=synthetic", "https://www.bilhealth.com/auth/callback?code=synthetic"
    ] { XCTAssertFalse(callback(raw, https: false), raw) }
  }

  func testCallbackRejectsTokenURLsEmptyOrRepeatedCodes() {
    for raw in [
      "https://www.bilhealth.com/auth/callback", "https://www.bilhealth.com/auth/callback?code=",
      "https://www.bilhealth.com/auth/callback?code=one&code=two",
      "https://www.bilhealth.com/auth/callback#access_token=synthetic",
      "https://www.bilhealth.com/auth/callback?code=synthetic&refresh_token=synthetic",
      "https://www.bilhealth.com/auth/callback?access_token=synthetic",
      "https://www.bilhealth.com/auth/callback?id_token=synthetic"
    ] { XCTAssertFalse(callback(raw, https: true), raw) }
  }

  func testProviderErrorsReturnToTheSameValidatedLocation() {
    XCTAssertTrue(callback("https://www.bilhealth.com/auth/callback?error=access_denied", https: true))
    XCTAssertTrue(callback("bil://auth-callback?error=access_denied", https: false))
    XCTAssertFalse(callback("bil://plans?error=access_denied", https: false))
  }

  func testAuthorizationRequiresTargetProjectFacebookPKCEAndExactRedirect() {
    XCTAssertTrue(authorization(https: true))
    XCTAssertTrue(authorization(https: false))
    XCTAssertFalse(authorization(https: true, host: "evil.example"))
    XCTAssertFalse(authorization(https: true, provider: "google"))
    XCTAssertFalse(authorization(https: true, redirect: "bil://auth-callback"))
    XCTAssertFalse(authorization(https: false, redirect: "https://www.bilhealth.com/auth/callback"))
    XCTAssertFalse(authorization(https: true, challenge: "short"))
    XCTAssertFalse(authorization(https: true, method: "plain"))
  }

  func testAuthorizationRejectsAmbiguousProviderAndInjectedToken() {
    XCTAssertFalse(authorization(https: true, extra: URLQueryItem(name: "provider", value: "facebook")))
    XCTAssertFalse(authorization(https: true, extra: URLQueryItem(name: "access_token", value: "synthetic")))
  }

  private func callback(_ raw: String, https: Bool) -> Bool {
    BILFacebookOAuthBridge.isAllowedCallbackURL(URL(string: raw)!, usesHTTPS: https)
  }

  private func authorization(https: Bool, host: String = "tgmanzhqulksykhslrzb.supabase.co",
                             provider: String = "facebook", redirect: String? = nil,
                             challenge: String = String(repeating: "a", count: 43),
                             method: String = "s256", extra: URLQueryItem? = nil) -> Bool {
    var components = URLComponents()
    components.scheme = "https"
    components.host = host
    components.path = "/auth/v1/authorize"
    components.queryItems = [
      URLQueryItem(name: "provider", value: provider),
      URLQueryItem(name: "redirect_to", value: redirect ?? (https ? "https://www.bilhealth.com/auth/callback" : "bil://auth-callback")),
      URLQueryItem(name: "code_challenge", value: challenge),
      URLQueryItem(name: "code_challenge_method", value: method)
    ]
    if let extra { components.queryItems?.append(extra) }
    return BILFacebookOAuthBridge.isAllowedAuthorizationURL(components.url!, usesHTTPS: https)
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
