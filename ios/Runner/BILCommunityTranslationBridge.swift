import Flutter
import UIKit
import SwiftUI
import NaturalLanguage
import Translation

/// Apple Translation runs on device. Never persists or logs UGC/owner data.
@MainActor
final class BILCommunityTranslationBridge {
  private let channel: FlutterMethodChannel
  private var requestId: String?
  private var pendingResult: FlutterResult?
  private var preparation: Task<Void, Never>?
  private var host: UIViewController?
  private var backgroundObserver: NSObjectProtocol?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "bil/community_translation", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(FlutterError(code: "translation_unavailable", message: nil, details: nil)); return }
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "cancel":
        if args["requestId"] as? String == self.requestId { self.finish(error: "translation_cancelled") }
        result(nil)
      case "translate":
        guard #available(iOS 18.0, *) else {
          result(FlutterError(code: "translation_unavailable", message: nil, details: nil)); return
        }
        guard let id = args["requestId"] as? String, !id.isEmpty,
              let texts = args["texts"] as? [String: String], !texts.isEmpty, texts.count <= 2,
              texts.values.allSatisfy({ $0.utf16.count <= 12000 }),
              let tag = args["targetTag"] as? String else {
          result(FlutterError(code: "invalid_input", message: nil, details: nil)); return
        }
        guard self.requestId == nil else {
          result(FlutterError(code: "translation_busy", message: nil, details: nil)); return
        }
        self.requestId = id; self.pendingResult = result
        self.start(id: id, texts: texts, tag: tag,
          status: args["statusLabel"] as? String ?? "Preparing translation…",
          cancel: args["cancelLabel"] as? String ?? "Cancel")
      default: result(FlutterMethodNotImplemented)
      }
    }
    backgroundObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in self?.finish(error: "translation_cancelled") }
    }
  }

  @available(iOS 18.0, *)
  private func start(id: String, texts: [String: String], tag: String, status: String, cancel: String) {
    preparation = Task { @MainActor [weak self] in
      guard let self else { return }
      let target = Locale.Language(identifier: tag)
      var entries: [BILTranslationEntry] = []
      var unchanged: [String: String] = [:]
      for (key, text) in texts.sorted(by: { $0.key < $1.key }) {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { unchanged[key] = text; continue }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let detected = recognizer.dominantLanguage else { self.finish(error: "language_unavailable"); return }
        let source = Locale.Language(identifier: detected.rawValue)
        if source.languageCode == target.languageCode &&
            (source.languageCode?.identifier != "zh" || source.script == target.script) {
          unchanged[key] = text; continue
        }
        let availability = await LanguageAvailability().status(from: source, to: target)
        guard self.requestId == id, !Task.isCancelled else { return }
        guard availability != .unsupported else { self.finish(error: "language_unavailable"); return }
        entries.append(BILTranslationEntry(key: key, text: text, source: source))
      }
      guard self.requestId == id, !Task.isCancelled else { return }
      if entries.isEmpty {
        self.finish(value: ["texts": texts, "engine": "apple", "sameLanguage": true]); return
      }
      guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            let presenter = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController,
            presenter.presentedViewController == nil else {
        self.finish(error: "translation_busy"); return
      }
      let model = BILTranslationVisit(entries: entries, target: target, output: unchanged)
      let view = BILTranslationPreparation(model: model, status: status, cancel: cancel,
        completion: { [weak self] output in
          guard let self, self.requestId == id else { return }
          self.finish(value: ["texts": output, "engine": "apple", "sameLanguage": false])
        }, failure: { [weak self] in
          guard let self, self.requestId == id else { return }
          self.finish(error: "translation_failed")
        }, cancelled: { [weak self] in
          guard let self, self.requestId == id else { return }
          self.finish(error: "translation_cancelled")
        })
      let controller = UIHostingController(rootView: view)
      controller.isModalInPresentation = true
      controller.modalPresentationStyle = .pageSheet
      controller.sheetPresentationController?.detents = [.medium()]
      self.host = controller
      presenter.present(controller, animated: !UIAccessibility.isReduceMotionEnabled)
    }
  }
  private func finish(value: Any? = nil, error: String? = nil) {
    guard let result = pendingResult else { return }
    requestId = nil; pendingResult = nil
    preparation?.cancel(); preparation = nil
    let controller = host; host = nil
    controller?.dismiss(animated: !UIAccessibility.isReduceMotionEnabled)
    if let error { result(FlutterError(code: error, message: nil, details: nil)) }
    else { result(value) }
  }
}

@available(iOS 18.0, *)
private struct BILTranslationEntry {
  let key: String
  let text: String
  let source: Locale.Language
}
@available(iOS 18.0, *)
@MainActor
private final class BILTranslationVisit: ObservableObject {
  let entries: [BILTranslationEntry]
  let target: Locale.Language
  var output: [String: String]
  var index = 0
  @Published var configuration: TranslationSession.Configuration
  init(entries: [BILTranslationEntry], target: Locale.Language, output: [String: String]) {
    self.entries = entries; self.target = target; self.output = output
    configuration = .init(source: entries[0].source, target: target)
  }
  func advance(_ translated: String) -> Bool {
    output[entries[index].key] = translated
    index += 1
    if index == entries.count { return false }
    var next = TranslationSession.Configuration(source: entries[index].source, target: target)
    // Also re-run when the next field uses the same language pair.
    next.invalidate()
    if next == configuration { next.invalidate() }
    configuration = next
    return true
  }
}
@available(iOS 18.0, *)
private struct BILTranslationPreparation: View {
  @ObservedObject var model: BILTranslationVisit
  let status: String
  let cancel: String
  let completion: ([String: String]) -> Void
  let failure: () -> Void
  let cancelled: () -> Void
  var body: some View {
    VStack(spacing: 20) {
      ProgressView(status)
      Button(cancel, action: cancelled)
    }.padding(24).translationTask(model.configuration) { session in
      let index = model.index
      do {
        // System permission/download UI; never a simulated permission dialog.
        try await session.prepareTranslation()
        let response = try await session.translate(model.entries[index].text)
        guard !Task.isCancelled, index == model.index else { return }
        if !model.advance(response.targetText) { completion(model.output) }
      } catch {
        if !Task.isCancelled, index == model.index { failure() }
      }
    }
  }
}
