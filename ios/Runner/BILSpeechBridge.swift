import AVFoundation
import Flutter
import Speech

final class BILSpeechBridge: NSObject, FlutterStreamHandler {
  private let methodChannel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private var eventSink: FlutterEventSink?
  private var audioEngine: AVAudioEngine?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?

  init(messenger: FlutterBinaryMessenger) {
    methodChannel = FlutterMethodChannel(name: "bil/speech", binaryMessenger: messenger)
    eventChannel = FlutterEventChannel(name: "bil/speech/events", binaryMessenger: messenger)
    super.init()
    methodChannel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    eventChannel.setStreamHandler(self)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "available":
      result(SFSpeechRecognizer.authorizationStatus() != .restricted)
    case "locales":
      result(SFSpeechRecognizer.supportedLocales().map(\.identifier).sorted())
    case "listen":
      let arguments = call.arguments as? [String: Any]
      authorizeAndStart(localeId: arguments?["localeId"] as? String, result: result)
    case "stop":
      stop(cancel: false)
      result(nil)
    case "cancel":
      stop(cancel: true)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func authorizeAndStart(localeId: String?, result: @escaping FlutterResult) {
    SFSpeechRecognizer.requestAuthorization { [weak self] speechStatus in
      guard speechStatus == .authorized else {
        self?.fail("speech_permission_denied", result: result)
        return
      }
      AVAudioApplication.requestRecordPermission { granted in
        guard granted else {
          self?.fail("microphone_permission_denied", result: result)
          return
        }
        DispatchQueue.main.async {
          self?.start(localeId: localeId, result: result)
        }
      }
    }
  }

  private func start(localeId: String?, result: @escaping FlutterResult) {
    stop(cancel: true)
    let locale = localeId.flatMap(Locale.init(identifier:)) ?? .current
    guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
      fail("speech_unavailable", result: result)
      return
    }

    let engine = AVAudioEngine()
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    input.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
      request.append(buffer)
    }

    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.record, mode: .measurement, options: .duckOthers)
      try session.setActive(true, options: .notifyOthersOnDeactivation)
      engine.prepare()
      try engine.start()
    } catch {
      input.removeTap(onBus: 0)
      fail("audio_session_unavailable", result: result)
      return
    }

    audioEngine = engine
    recognitionRequest = request
    recognitionTask = recognizer.recognitionTask(with: request) { [weak self] response, error in
      if let response {
        self?.eventSink?([
          "type": "result",
          "words": response.bestTranscription.formattedString,
          "final": response.isFinal,
        ])
        if response.isFinal { self?.stop(cancel: false) }
      }
      if error != nil {
        self?.eventSink?([
          "type": "error",
          "code": response == nil ? "speech_no_match" : "recognizer_error",
        ])
        self?.stop(cancel: true)
      }
    }
    eventSink?(["type": "status", "listening": true])
    result(nil)
  }

  private func fail(_ code: String, result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(["type": "error", "code": code])
      result(FlutterError(code: code, message: nil, details: nil))
    }
  }

  private func stop(cancel: Bool) {
    audioEngine?.stop()
    audioEngine?.inputNode.removeTap(onBus: 0)
    recognitionRequest?.endAudio()
    if cancel { recognitionTask?.cancel() } else { recognitionTask?.finish() }
    recognitionTask = nil
    recognitionRequest = nil
    audioEngine = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    eventSink?(["type": "status", "listening": false])
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  deinit {
    stop(cancel: true)
    methodChannel.setMethodCallHandler(nil)
    eventChannel.setStreamHandler(nil)
  }
}
