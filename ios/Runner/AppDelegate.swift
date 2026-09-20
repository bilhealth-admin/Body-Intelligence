import Flutter
import ContactsUI
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, CNContactPickerDelegate {
  private var speechBridge: BILSpeechBridge?
  private var textToSpeechBridge: BILTextToSpeechBridge?
  private var micSoundBridge: BILMicSoundBridge?
  private var appleSignInLifecycleBridge: BILAppleSignInLifecycleBridge?
  private var appAttestBridge: BILAppAttestBridge?
  private var pushResult: FlutterResult?
  private var pushToken: String?
  private var pushChannel: FlutterMethodChannel?
  private var pendingRemotePushDeepLinks: [String] = []
  private var remotePushDeliveryInFlight = false
  private var contactPickerResult: FlutterResult?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // FlutterAppDelegate forwards local-notification callbacks to registered
    // plugins. Making it the UNUserNotificationCenter delegate also gives BIL
    // one lifecycle-safe seam for remote APNs presentation and tap routing.
    UNUserNotificationCenter.current().delegate = self
    if let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any],
       let payload = remotePushDeepLink(from: userInfo) {
      enqueueRemotePushDeepLink(payload)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    BILGlobalHealthBridge.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "BILGlobalHealthBridge")!)
    BILFitnessBleBridge.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "BILFitnessBleBridge")!)
    BILSystemCryptoBridge.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "BILSystemCryptoBridge")!)
    let appleLifecycleRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "BILAppleSignInLifecycleBridge")!
    appleSignInLifecycleBridge = BILAppleSignInLifecycleBridge(messenger: appleLifecycleRegistrar.messenger())
    let appAttestRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "BILAppAttestBridge")!
    appAttestBridge = BILAppAttestBridge(messenger: appAttestRegistrar.messenger())
    let speechRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "BILSpeechBridge")!
    speechBridge = BILSpeechBridge(messenger: speechRegistrar.messenger())
    textToSpeechBridge = BILTextToSpeechBridge(messenger: speechRegistrar.messenger())
    micSoundBridge = BILMicSoundBridge(messenger: speechRegistrar.messenger())
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BILPushBridge")!
    let channel = FlutterMethodChannel(name: "bil/push", binaryMessenger: registrar.messenger())
    pushChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(FlutterError(code: "push_unavailable", message: nil, details: nil)); return }
      switch call.method {
      case "providerStatus":
        result([
          "configured": true,
          "tokenRegistration": true,
          "remoteTapRouting": true,
          "provider": "apns",
        ])
      case "requestToken":
        if let token = self.pushToken { result(token); return }
        guard self.pushResult == nil else {
          result(FlutterError(code: "push_request_in_progress", message: nil, details: nil)); return
        }
        self.pushResult = result
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
          if let error {
            self.finishPush(FlutterError(
              code: "push_permission_failed",
              message: error.localizedDescription,
              details: nil
            ))
            return
          }
          guard granted else { self.finishPush(FlutterError(code: "push_permission_denied", message: nil, details: nil)); return }
          DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }
      case "deleteToken":
        self.pushToken = nil
        DispatchQueue.main.async {
          UIApplication.shared.unregisterForRemoteNotifications()
        }
        result(nil)
      case "takeInitialPayload":
        let payloads = self.pendingRemotePushDeepLinks
        self.pendingRemotePushDeepLinks.removeAll(keepingCapacity: true)
        result(payloads)
      default: result(FlutterMethodNotImplemented)
      }
    }
    FlutterMethodChannel(name: "bil/contact_picker", binaryMessenger: registrar.messenger()).setMethodCallHandler { [weak self] call, result in
      guard let self else { result(FlutterError(code: "contact_picker_unavailable", message: nil, details: nil)); return }
      guard call.method == "pick" else { result(FlutterMethodNotImplemented); return }
      guard self.contactPickerResult == nil else {
        result(FlutterError(code: "contact_picker_in_progress", message: nil, details: nil)); return
      }
      self.contactPickerResult = result
      let picker = CNContactPickerViewController()
      picker.delegate = self
      picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
      DispatchQueue.main.async {
        guard let presenter = self.activePresenter() else {
          self.finishContactPicker(FlutterError(
            code: "contact_picker_unavailable",
            message: "No active iOS scene is available to present the contact picker.",
            details: nil
          ))
          return
        }
        presenter.present(picker, animated: true)
      }
    }
  }

  func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
    let contact = contactProperty.contact
    let name = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
    let phone = (contactProperty.value as? CNPhoneNumber)?.stringValue ?? ""
    finishContactPicker(["name": name, "phone": phone])
  }

  func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
    let name = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
    let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
    finishContactPicker(["name": name, "phone": phone])
  }

  func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
    finishContactPicker(nil)
  }

  /// Returns the visible controller for the foreground scene. Once an app
  /// adopts UIScene, AppDelegate.window is allowed to be nil, so presenting
  /// from that legacy property can silently leave the Flutter Future pending.
  private func activePresenter() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .sorted { lhs, rhs in
        lhs.activationState == .foregroundActive && rhs.activationState != .foregroundActive
      }

    for scene in scenes {
      let window = scene.windows.first(where: { $0.isKeyWindow })
        ?? scene.windows.first(where: { !$0.isHidden && $0.alpha > 0 })
      if let root = window?.rootViewController {
        return visibleViewController(from: root)
      }
    }
    return nil
  }

  private func visibleViewController(from controller: UIViewController) -> UIViewController {
    if let presented = controller.presentedViewController {
      return visibleViewController(from: presented)
    }
    if let navigation = controller as? UINavigationController,
       let visible = navigation.visibleViewController {
      return visibleViewController(from: visible)
    }
    if let tabs = controller as? UITabBarController,
       let selected = tabs.selectedViewController {
      return visibleViewController(from: selected)
    }
    return controller
  }

  private func finishContactPicker(_ value: Any?) {
    contactPickerResult?(value)
    contactPickerResult = nil
  }

  private func finishPush(_ value: Any?) {
    DispatchQueue.main.async { self.pushResult?(value); self.pushResult = nil }
  }

  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    pushToken = token
    finishPush(token)
  }

  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    finishPush(FlutterError(code: "apns_registration_failed", message: error.localizedDescription, details: nil))
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    guard notification.request.trigger is UNPushNotificationTrigger else {
      super.userNotificationCenter(
        center,
        willPresent: notification,
        withCompletionHandler: completionHandler
      )
      return
    }

    // A remote notification received while BIL is visible must remain visible
    // to the user. The system still applies the user's notification settings.
    completionHandler([.banner, .list, .sound, .badge])
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    guard response.notification.request.trigger is UNPushNotificationTrigger else {
      super.userNotificationCenter(
        center,
        didReceive: response,
        withCompletionHandler: completionHandler
      )
      return
    }

    if response.actionIdentifier == UNNotificationDefaultActionIdentifier,
       let payload = remotePushDeepLink(
         from: response.notification.request.content.userInfo
       ) {
      deliverRemotePushTap(payload)
    }
    completionHandler()
  }

  private func remotePushDeepLink(from userInfo: [AnyHashable: Any]) -> String? {
    let direct = userInfo["deep_link"] as? String
    let nested = (userInfo["data"] as? [String: Any])?["deep_link"] as? String
    guard let value = (direct ?? nested)?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty,
          value.utf8.count <= 512,
          let url = URL(string: value),
          url.scheme?.lowercased() == "bil" else {
      return nil
    }
    return value
  }

  private func deliverRemotePushTap(_ payload: String) {
    enqueueRemotePushDeepLink(payload)
    deliverNextRemotePushTap()
  }

  private func enqueueRemotePushDeepLink(_ payload: String) {
    guard !pendingRemotePushDeepLinks.contains(payload),
          pendingRemotePushDeepLinks.count < 32 else { return }
    pendingRemotePushDeepLinks.append(payload)
  }

  private func deliverNextRemotePushTap() {
    guard !remotePushDeliveryInFlight,
          let payload = pendingRemotePushDeepLinks.first,
          let channel = pushChannel else { return }
    remotePushDeliveryInFlight = true
    channel.invokeMethod("notificationTap", arguments: payload) { [weak self] result in
      guard let self else { return }
      self.remotePushDeliveryInFlight = false
      if result as? Bool == true, self.pendingRemotePushDeepLinks.first == payload {
        self.pendingRemotePushDeepLinks.removeFirst()
        self.deliverNextRemotePushTap()
      }
    }
  }
}
