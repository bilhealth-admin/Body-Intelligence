import AuthenticationServices
import Flutter
import Foundation

/// Bridges Apple's process-level credential-revocation notification to the
/// Flutter session authority. Credential-state decisions remain in Dart,
/// where the notification is reconciled against the owner-scoped Apple ID.
final class BILAppleSignInLifecycleBridge {
  private static let channelName = "bil/apple_sign_in_lifecycle"

  private let channel: FlutterMethodChannel
  private var revocationObserver: NSObjectProtocol?
  private var dartIsObserving = false
  private var hasPendingRevocation = false

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(
          code: "apple_lifecycle_unavailable",
          message: nil,
          details: nil
        ))
        return
      }
      switch call.method {
      case "startObserving":
        self.dartIsObserving = true
        let pending = self.hasPendingRevocation
        self.hasPendingRevocation = false
        result(nil)
        if pending {
          self.channel.invokeMethod("credentialRevoked", arguments: nil)
        }
      case "stopObserving":
        self.dartIsObserving = false
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    revocationObserver = NotificationCenter.default.addObserver(
      forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.credentialWasRevoked()
    }
  }

  deinit {
    if let revocationObserver {
      NotificationCenter.default.removeObserver(revocationObserver)
    }
  }

  private func credentialWasRevoked() {
    guard dartIsObserving else {
      hasPendingRevocation = true
      return
    }
    channel.invokeMethod("credentialRevoked", arguments: nil)
  }
}
