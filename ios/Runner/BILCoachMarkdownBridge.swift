import Flutter
import SwiftUI
import CoreText

final class BILCoachMarkdownFactory: NSObject, FlutterPlatformViewFactory {
  private let registrar: FlutterPluginRegistrar
  init(registrar: FlutterPluginRegistrar) { self.registrar = registrar }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64,
              arguments args: Any?) -> FlutterPlatformView {
    BILCoachMarkdownPlatformView(frame: frame, id: viewId,
      arguments: args as? [String: Any] ?? [:], registrar: registrar)
  }
}

private final class BILCoachMarkdownPlatformView: NSObject, FlutterPlatformView {
  private let channel: FlutterMethodChannel
  private let host: UIHostingController<AnyView>
  private var generation = ""
  private var lastHeight: CGFloat = 0
  private static var registeredFonts: [String: String] = [:]

  init(frame: CGRect, id: Int64, arguments: [String: Any],
       registrar: FlutterPluginRegistrar) {
    channel = FlutterMethodChannel(name: "bil/coach_markdown/\(id)",
                                   binaryMessenger: registrar.messenger())
    host = UIHostingController(rootView: AnyView(BILCoachMarkdownView(
      blocks: [], rightToLeft: false, fontSize: 16, textColor: .primary,
      linkColor: .blue, fontName: nil, openLink: { _ in }, reportHeight: { _ in })))
    super.init()
    host.view.frame = frame
    host.view.backgroundColor = .clear
    host.view.isOpaque = false
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      guard call.method == "update", let data = call.arguments as? [String: Any]
      else { result(FlutterMethodNotImplemented); return }
      self.update(data, registrar: registrar)
      result(nil)
    }
    update(arguments, registrar: registrar)
  }

  private func update(_ data: [String: Any], registrar: FlutterPluginRegistrar) {
    guard let text = data["text"] as? String,
          let token = data["generation"] as? String,
          let size = data["fontSize"] as? Double, size.isFinite, size >= 8, size <= 120,
          let foreground = data["foreground"] as? NSNumber,
          let accent = data["accent"] as? NSNumber else { return }
    generation = token
    lastHeight = 0
    let rtl = data["rtl"] as? Bool ?? false
    let asset = rtl ? "assets/fonts/NotoNaskhArabic-Regular.ttf" : nil
    let name = asset.flatMap { Self.fontName($0, registrar: registrar) }
    host.rootView = AnyView(BILCoachMarkdownView(
      blocks: BILCoachMarkdownDocument.blocks(text), rightToLeft: rtl,
      fontSize: size, textColor: Self.color(foreground), linkColor: Self.color(accent),
      fontName: name,
      openLink: { [weak self] url in
        self?.channel.invokeMethod("openLink", arguments: ["generation": token, "url": url.absoluteString])
      },
      reportHeight: { [weak self] height in
        guard let self, self.generation == token, height.isFinite, height > 0,
              abs(height - self.lastHeight) > 0.5 else { return }
        self.lastHeight = height
        self.channel.invokeMethod("height", arguments: ["generation": token, "height": Double(height)])
      },
      reportFirstBlock: { [weak self] rect in
        guard let self, self.generation == token, !rect.isEmpty,
              rect.origin.x.isFinite, rect.origin.y.isFinite,
              rect.width.isFinite, rect.height.isFinite else { return }
        self.channel.invokeMethod("contentBounds", arguments: ["generation": token,
          "x": Double(rect.minX), "y": Double(rect.minY),
          "width": Double(rect.width), "height": Double(rect.height)])
      }).id(token))
  }

  private static func color(_ number: NSNumber) -> Color {
    let value = number.uint32Value
    return Color(.sRGB, red: Double((value >> 16) & 255) / 255,
      green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255,
      opacity: Double((value >> 24) & 255) / 255)
  }

  private static func fontName(_ asset: String, registrar: FlutterPluginRegistrar) -> String? {
    if let name = registeredFonts[asset] { return name }
    let key = registrar.lookupKey(forAsset: asset)
    guard let path = Bundle.main.path(forResource: key, ofType: nil),
          let provider = CGDataProvider(filename: path), let font = CGFont(provider),
          let name = font.postScriptName as String? else { return nil }
    CTFontManagerRegisterGraphicsFont(font, nil)
    registeredFonts[asset] = name
    return name
  }

  func view() -> UIView { host.view }
  deinit { channel.setMethodCallHandler(nil) }
}
