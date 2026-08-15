import Flutter
import ContactsUI
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, CNContactPickerDelegate {
  private var speechBridge: BILSpeechBridge?
  private var textToSpeechBridge: BILTextToSpeechBridge?
  private var pushResult: FlutterResult?
  private var pushToken: String?
  private var contactPickerResult: FlutterResult?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    BILGlobalHealthBridge.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "BILGlobalHealthBridge")!)
    BILMedicalBleBridge.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "BILMedicalBleBridge")!)
    let speechRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "BILSpeechBridge")!
    speechBridge = BILSpeechBridge(messenger: speechRegistrar.messenger())
    textToSpeechBridge = BILTextToSpeechBridge(messenger: speechRegistrar.messenger())
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BILPushBridge")!
    FlutterMethodChannel(name: "bil/push", binaryMessenger: registrar.messenger()).setMethodCallHandler { [weak self] call, result in
      guard let self else { result(FlutterError(code: "push_unavailable", message: nil, details: nil)); return }
      switch call.method {
      case "requestToken":
        if let token = self.pushToken { result(token); return }
        self.pushResult = result
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
          guard granted else { self.finishPush(FlutterError(code: "push_permission_denied", message: nil, details: nil)); return }
          DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }
      case "deleteToken": self.pushToken = nil; result(nil)
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
      DispatchQueue.main.async { self.window?.rootViewController?.present(picker, animated: true) }
    }
  }

  func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
    let contact = contactProperty.contact
    let name = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
    let phone = (contactProperty.value as? CNPhoneNumber)?.stringValue ?? ""
    contactPickerResult?(["name": name, "phone": phone])
    contactPickerResult = nil
  }

  func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
    let name = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
    let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
    contactPickerResult?(["name": name, "phone": phone])
    contactPickerResult = nil
  }

  func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
    contactPickerResult?(nil)
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
}
