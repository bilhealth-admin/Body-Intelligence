import AuthenticationServices
import Flutter
import UIKit

/// Owns one OS authentication session. No callback URL enters a log or website
/// bridge; legacy scheme callbacks are accepted only by this session completion.
final class BILFacebookOAuthBridge: NSObject, ASWebAuthenticationPresentationContextProviding {
  // ASWebAuthenticationSession owns this callback; no HTTPS association is needed.
  static let callbackMode = "legacy"
  private let channel: FlutterMethodChannel
  private var session: ASWebAuthenticationSession?
  private var activeAttempt: String?
  private var pendingResult: FlutterResult?
  private var deadline: DispatchWorkItem?
  private weak var presentationWindow: UIWindow?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "bil/facebook_oauth", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "facebook_oauth_unavailable", message: nil, details: nil)); return
      }
      switch call.method {
      case "callbackMode":
        result(Self.callbackMode)
      case "authenticate":
        self.authenticate(call.arguments, result: result)
      case "cancel":
        let args = call.arguments as? [String: Any]
        if let attempt = args?["attemptId"] as? String, attempt == self.activeAttempt {
          self.finish(attempt, value: nil, cancel: true)
        }
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  deinit {
    deadline?.cancel()
    session?.cancel()
    pendingResult?(nil)
  }

  private func authenticate(_ arguments: Any?, result: @escaping FlutterResult) {
    guard activeAttempt == nil,
          let args = arguments as? [String: Any],
          let attempt = args["attemptId"] as? String,
          attempt.range(of: "^[A-Za-z0-9_-]{43}$", options: .regularExpression) != nil,
          let rawURL = args["url"] as? String,
          let url = URL(string: rawURL), isAllowedAuthorizationURL(url),
          let window = activeWindow() else {
      result(FlutterError(code: "facebook_oauth_start_failed", message: nil, details: nil)); return
    }
    activeAttempt = attempt
    pendingResult = result
    presentationWindow = window
    let completion: ASWebAuthenticationSession.CompletionHandler = { [weak self] url, error in
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        guard self.activeAttempt == attempt else {
          self.recordDiagnostic("native_callback", "retired_completion"); return
        }
        if let error = error as? ASWebAuthenticationSessionError,
           error.code == .canceledLogin {
          self.recordDiagnostic("native_callback", "cancelled")
          self.finish(attempt, value: nil); return
        }
        guard error == nil else {
          self.recordDiagnostic("native_callback", "os_error")
          self.finish(attempt, value: FlutterError(code: "facebook_oauth_failed", message: nil, details: nil)); return
        }
        guard let url else {
          self.recordDiagnostic("native_callback", "missing_url")
          self.finish(attempt, value: FlutterError(code: "facebook_oauth_failed", message: nil, details: nil)); return
        }
        guard let clean = Self.normalizedOwnedCallbackURL(url, usesHTTPS: Self.callbackMode == "https") else {
          self.recordDiagnostic("native_callback", Self.callbackRejectionReason(url, usesHTTPS: Self.callbackMode == "https") ?? "callback_rejected")
          self.finish(attempt, value: FlutterError(code: "facebook_oauth_failed", message: nil, details: nil)); return
        }
        let marker = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedFragment
        self.recordDiagnostic("native_callback", marker == "_=_" ? "facebook_marker_removed" : (marker == "" ? "empty_fragment_removed" : "accepted"))
        self.finish(attempt, value: ["attemptId": attempt, "callbackUrl": clean.absoluteString])
      }
    }
    let authSession: ASWebAuthenticationSession
    if #available(iOS 17.4, *) {
      authSession = ASWebAuthenticationSession(
        url: url, callback: .customScheme("bil"),
        completionHandler: completion)
    } else {
      authSession = ASWebAuthenticationSession(
        url: url, callbackURLScheme: "bil", completionHandler: completion)
    }
    authSession.presentationContextProvider = self
    session = authSession
    guard authSession.start() else {
      recordDiagnostic("native_start", "failed")
      finish(attempt, value: FlutterError(code: "facebook_oauth_start_failed", message: nil, details: nil), cancel: true); return
    }
    recordDiagnostic("native_start", "started")
    let timeout = DispatchWorkItem { [weak self] in
      self?.recordDiagnostic("native_callback", "timeout")
      self?.finish(attempt, value: FlutterError(code: "facebook_oauth_timeout", message: nil, details: nil), cancel: true)
    }
    deadline = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 300, execute: timeout)
  }

  private func recordDiagnostic(_ stage: String, _ reason: String) {
    // Only fixed local codes. Never log a callback, code, token or error text.
    NSLog("BIL_FACEBOOK_OAUTH stage=%@ reason=%@", stage, reason)
  }

  private func finish(_ attempt: String, value: Any?, cancel: Bool = false) {
    guard activeAttempt == attempt else { return }
    let result = pendingResult
    let current = session
    // Clear ownership before cancel invokes any late system completion.
    activeAttempt = nil
    pendingResult = nil
    session = nil
    presentationWindow = nil
    deadline?.cancel()
    deadline = nil
    if cancel { current?.cancel() }
    result?(value)
  }

  private func activeWindow() -> UIWindow? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }
    return scenes.flatMap(\.windows).first { $0.isKeyWindow }
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    // start() is called only after capturing a foreground key window.
    return presentationWindow ?? ASPresentationAnchor()
  }

  private func isAllowedAuthorizationURL(_ url: URL) -> Bool {
    Self.isAllowedAuthorizationURL(url, usesHTTPS: Self.callbackMode == "https")
  }

  private static func expectedCallback(usesHTTPS: Bool) -> String {
    usesHTTPS ? "https://www.bilhealth.com/auth/callback" : "bil://auth-callback"
  }

  // Pure native policy is shared by the production session and XCTest cases.
  static func isAllowedAuthorizationURL(_ url: URL, usesHTTPS: Bool) -> Bool {
    guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
          c.scheme == "https", c.host == "tgmanzhqulksykhslrzb.supabase.co",
          c.path == "/auth/v1/authorize", c.user == nil, c.password == nil,
          c.port == nil, c.fragment == nil, let items = c.queryItems else { return false }
    let values = Dictionary(grouping: items, by: \.name)
    guard values.values.allSatisfy({ $0.count == 1 }),
          values["provider"]?.first?.value == "facebook",
          values["redirect_to"]?.first?.value == expectedCallback(usesHTTPS: usesHTTPS),
          values["code_challenge_method"]?.first?.value?.lowercased() == "s256",
          let challenge = values["code_challenge"]?.first?.value,
          challenge.range(of: "^[A-Za-z0-9_-]{43}$", options: .regularExpression) != nil else { return false }
    return !items.contains { ["access_token", "refresh_token", "id_token"].contains($0.name) }
  }

  static func isAllowedCallbackURL(_ url: URL, usesHTTPS: Bool) -> Bool {
    callbackRejectionReason(url, usesHTTPS: usesHTTPS) == nil
  }

  // Production calls this only from the active ASWebAuthenticationSession's
  // completion. This pure helper does not grant a session or exchange a code.
  static func normalizedOwnedCallbackURL(_ url: URL, usesHTTPS: Bool) -> URL? {
    guard isAllowedCallbackURL(url, usesHTTPS: usesHTTPS),
          var c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
    c.fragment = nil
    return c.url
  }

  static func callbackRejectionReason(_ url: URL, usesHTTPS: Bool) -> String? {
    guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let expected = URLComponents(string: expectedCallback(usesHTTPS: usesHTTPS)),
          c.scheme == expected.scheme, c.host == expected.host, c.path == expected.path,
          c.user == nil, c.password == nil, c.port == nil else { return "origin_or_path_rejected" }
    let fragment = c.percentEncodedFragment
    if let fragment, !fragment.isEmpty, fragment != "_=_" {
      return fragment.hasPrefix("error=") || fragment.hasPrefix("error_code=") || fragment.hasPrefix("error_description=")
        ? "provider_error_fragment_rejected" : "fragment_rejected"
    }
    guard let items = c.queryItems else { return "missing_query" }
    let values = Dictionary(grouping: items, by: \.name)
    guard values.values.allSatisfy({ $0.count == 1 }) else { return "duplicate_query_rejected" }
    guard !items.contains(where: { ["access_token", "refresh_token", "id_token"].contains($0.name) }) else { return "token_query_rejected" }
    guard values["code"]?.first?.value?.isEmpty == false ||
      ["error", "error_code", "error_description"].contains(where: { values[$0] != nil }) else { return "missing_code_or_error" }
    return nil
  }
}
