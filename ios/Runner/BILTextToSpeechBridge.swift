import AVFoundation
import Flutter

final class BILTextToSpeechBridge: NSObject, AVSpeechSynthesizerDelegate {
  private let synthesizer = AVSpeechSynthesizer()
  private let channel: FlutterMethodChannel
  private var pendingSpeechResult: FlutterResult?
  private var pendingUtterance: AVSpeechUtterance?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "bil/tts", binaryMessenger: messenger)
    super.init()
    synthesizer.delegate = self
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
      pendingSpeechResult?(FlutterError(code: "tts_stopped", message: nil, details: nil))
      pendingSpeechResult = nil
      pendingUtterance = nil
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
      let requestedLanguage = locale.replacingOccurrences(of: "_", with: "-")
      let language = requestedLanguage.lowercased() == "zh-hans" ? "zh-CN" :
        requestedLanguage.lowercased() == "zh-hant" ? "zh-TW" : requestedLanguage
      let requestedGender = (arguments["voiceGender"] as? String) ?? "system"
      let languageCode = String(language.prefix(2)).lowercased()
      let requiresExactVoice = language.contains("-")
      let matchingVoice: AVSpeechSynthesisVoice? = {
        guard #available(iOS 13.0, *) else { return nil }
        let gender: AVSpeechSynthesisVoiceGender = requestedGender == "female"
          ? .female : requestedGender == "male" ? .male : .unspecified
        guard gender != .unspecified else { return nil }
        return AVSpeechSynthesisVoice.speechVoices().first { candidate in
          candidate.gender == gender &&
            (requiresExactVoice
              ? candidate.language.lowercased() == language.lowercased()
              : candidate.language.lowercased().hasPrefix(languageCode))
        }
      }()
      guard let voice = matchingVoice ?? AVSpeechSynthesisVoice(language: language) ??
        (requiresExactVoice ? nil : AVSpeechSynthesisVoice(language: languageCode))
      else {
        result(FlutterError(code: "tts_locale_unavailable", message: locale, details: nil))
        return
      }
      synthesizer.stopSpeaking(at: .immediate)
      pendingSpeechResult?(FlutterError(code: "tts_stopped", message: nil, details: nil))
      let utterance = AVSpeechUtterance(string: text)
      utterance.voice = voice
      utterance.rate = 0.48
      utterance.pitchMultiplier = requestedGender == "male" ? 0.82 :
        requestedGender == "female" ? 1.08 : 1.0
      pendingSpeechResult = result
      pendingUtterance = utterance
      synthesizer.speak(utterance)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didFinish utterance: AVSpeechUtterance
  ) {
    guard pendingUtterance === utterance else { return }
    pendingSpeechResult?(nil)
    pendingSpeechResult = nil
    pendingUtterance = nil
  }

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didCancel utterance: AVSpeechUtterance
  ) {
    guard pendingUtterance === utterance else { return }
    pendingSpeechResult?(FlutterError(code: "tts_stopped", message: nil, details: nil))
    pendingSpeechResult = nil
    pendingUtterance = nil
  }
}
