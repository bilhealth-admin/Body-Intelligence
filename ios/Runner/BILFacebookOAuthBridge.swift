import AuthenticationServices
import Flutter
import UIKit

/// Owns one OS authentication session. No callback URL enters a log or website
/// bridge; legacy scheme callbacks are accepted only by this session completion.
final class BILFacebookOAuthBridge: NSObject, ASWebAuthenticationPresentationContextProviding {
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
        if #available(iOS 17.4, *) { result("https") } else { result("legacy") }
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
        guard let self, self.activeAttempt == attempt else { return }
        if let error = error as? ASWebAuthenticationSessionError,
           error.code == .canceledLogin {
          self.finish(attempt, value: nil); return
        }
        guard error == nil, let url, self.isAllowedCallbackURL(url) else {
          self.finish(attempt, value: FlutterError(code: "facebook_oauth_failed", message: nil, details: nil)); return
        }
        self.finish(attempt, value: ["attemptId": attempt, "callbackUrl": url.absoluteString])
      }
    }
    let authSession: ASWebAuthenticationSession
    if #available(iOS 17.4, *) {
      authSession = ASWebAuthenticationSession(
        url: url, callback: .https(host: "www.bilhealth.com", path: "/auth/callback"),
        completionHandler: completion)
    } else {
      authSession = ASWebAuthenticationSession(
        url: url, callbackURLScheme: "bil", completionHandler: completion)
    }
    authSession.presentationContextProvider = self
    session = authSession
    guard authSession.start() else {
      finish(attempt, value: FlutterError(code: "facebook_oauth_start_failed", message: nil, details: nil), cancel: true); return
    }
    let timeout = DispatchWorkItem { [weak self] in
      self?.finish(attempt, value: FlutterError(code: "facebook_oauth_timeout", message: nil, details: nil), cancel: true)
    }
    deadline = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 300, execute: timeout)
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

  private var usesHTTPSCallback: Bool {
    if #available(iOS 17.4, *) { return true }
    return false
  }

  private func isAllowedAuthorizationURL(_ url: URL) -> Bool {
    Self.isAllowedAuthorizationURL(url, usesHTTPS: usesHTTPSCallback)
  }

  private func isAllowedCallbackURL(_ url: URL) -> Bool {
    Self.isAllowedCallbackURL(url, usesHTTPS: usesHTTPSCallback)
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
    guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let expected = URLComponents(string: expectedCallback(usesHTTPS: usesHTTPS)),
          c.scheme == expected.scheme, c.host == expected.host, c.path == expected.path,
          c.user == nil, c.password == nil, c.port == nil, c.fragment == nil,
          let items = c.queryItems else { return false }
    let values = Dictionary(grouping: items, by: \.name)
    guard values.values.allSatisfy({ $0.count == 1 }),
          !items.contains(where: { ["access_token", "refresh_token", "id_token"].contains($0.name) }) else { return false }
    return values["code"]?.first?.value?.isEmpty == false ||
      ["error", "error_code", "error_description"].contains { values[$0] != nil }
  }
}
