import Flutter
import UIKit

/// App-wide semantic SF Symbols rendered by UIKit on the user's OS.
/// No exported Apple font, downloaded artwork, network access or platform view.
final class BILSettingsSymbolsBridge: NSObject, FlutterPlugin {
  private let cache = NSCache<NSString, NSData>()
  private static let symbols: [String: String] = [
    "profile": "person.crop.circle.fill", "camera": "camera.fill",
    "email": "at", "height": "arrow.up.and.down", "people": "person.2.fill",
    "calendar": "calendar", "location": "location.fill", "postal": "envelope.fill",
    "time": "clock.fill", "measure": "ruler.fill", "nutrition": "fork.knife",
    "goals": "flag.fill", "preferences": "slider.horizontal.3", "language": "globe",
    "appearance": "circle.lefthalf.filled", "privacy": "hand.raised.fill",
    "exercise": "figure.walk", "notifications": "bell.fill", "health": "heart.fill",
    "cloud": "arrow.triangle.2.circlepath", "support": "questionmark.circle.fill",
    "moderation": "checkmark.shield.fill", "weight": "scalemass.fill",
    "foodSearch": "magnifyingglass",
    "barcode": "barcode.viewfinder",
    "voice": "mic.fill",
    "notes": "note.text",
    "water": "drop.fill",
    "breakfast": "sunrise.fill",
    "lunch": "sun.max.fill",
    "dinner": "moon.stars.fill",
    "snack": "bag.fill",
    "progress": "chart.line.uptrend.xyaxis",
    "report": "chart.bar.fill",
    "challenges": "rosette",
    "recipes": "book.closed.fill",
    "fasting": "timer",
    "sleep": "bed.double.fill",
    "devices": "applewatch",
    "learn": "graduationcap.fill",
    "messages": "bubble.left.and.bubble.right.fill",
    "aiCoach": "sparkles",
    "verifiedFood": "checkmark.seal.fill",
    "export": "square.and.arrow.down.fill",
    "accountDeletion": "person.crop.circle.badge.minus",
    "legal": "doc.text.fill",
    "heartRate": "waveform.path.ecg",
    "distance": "arrow.left.and.right",
    "bodyFat": "percent",
    "oxygen": "lungs.fill",
    "dashboard": "square.grid.2x2.fill",
    "discover": "safari.fill",
    "more": "ellipsis",
    "diary": "book.fill",
  ]

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = BILSettingsSymbolsBridge()
    instance.cache.countLimit = 72
    let channel = FlutterMethodChannel(name: "bil/settings_symbols", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "render" else { result(FlutterMethodNotImplemented); return }
    guard let args = call.arguments as? [String: Any],
          let key = args["symbol"] as? String,
          let name = Self.symbols[key],
          let requested = args["pixels"] as? NSNumber else {
      result(FlutterError(code: "invalid_symbol", message: nil, details: nil)); return
    }
    let pixels = max(16, min(128, requested.intValue))
    let cacheKey = "\(key):\(pixels)" as NSString
    if let bytes = cache.object(forKey: cacheKey) {
      result(FlutterStandardTypedData(bytes: bytes as Data)); return
    }
    let configuration = UIImage.SymbolConfiguration(pointSize: CGFloat(pixels) * 0.82, weight: .regular)
    guard let image = UIImage(systemName: name, withConfiguration: configuration)?.withTintColor(.white, renderingMode: .alwaysOriginal) else {
      result(nil); return
    }
    let side = CGFloat(pixels)
    let scale = min(side / image.size.width, side / image.size.height)
    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = false
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
    let output = renderer.image { _ in
      image.draw(in: CGRect(x: (side - size.width) / 2, y: (side - size.height) / 2, width: size.width, height: size.height))
    }
    guard let bytes = output.pngData() else { result(nil); return }
    cache.setObject(bytes as NSData, forKey: cacheKey)
    result(FlutterStandardTypedData(bytes: bytes))
  }
}
