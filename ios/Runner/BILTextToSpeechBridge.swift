import AVFoundation
import Flutter

final class BILTextToSpeechBridge {
  private let synthesizer = AVSpeechSynthesizer()
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "bil/tts", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: FlutterResult) {
    switch call.method {
    case "available":
      result(true)
    case "stop":
      synthesizer.stopSpeaking(at: .immediate)
      result(nil)
    case "speak":
      guard
        let arguments = call.arguments as? [String: Any],
        let text = arguments["text"] as? String,
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        result(FlutterError(code: "tts_invalid_text", message: nil, details: nil))
        return
      }
      let locale = (arguments["locale"] as? String) ?? "en"
      let language = locale.replacingOccurrences(of: "_", with: "-")
      guard let voice = AVSpeechSynthesisVoice(language: language) ??
        AVSpeechSynthesisVoice(language: String(language.prefix(2)))
      else {
        result(FlutterError(code: "tts_locale_unavailable", message: locale, details: nil))
        return
      }
      synthesizer.stopSpeaking(at: .immediate)
      let utterance = AVSpeechUtterance(string: text)
      utterance.voice = voice
      utterance.rate = 0.48
      synthesizer.speak(utterance)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
