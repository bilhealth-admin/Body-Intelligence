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
  private var inputTapInstalled = false
  private var startInFlight = false
  private var pendingStartResult: FlutterResult?

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
      switch SFSpeechRecognizer.authorizationStatus() {
      case .authorized, .notDetermined:
        result(true)
      case .denied, .restricted:
        result(false)
      @unknown default:
        result(false)
      }
    case "locales":
      result(SFSpeechRecognizer.supportedLocales().map(\.identifier).sorted())
    case "listen":
      guard !startInFlight else {
        result(FlutterError(code: "speech_start_in_progress", message: nil, details: nil))
        return
      }
      guard audioEngine == nil, recognitionTask == nil else {
        result(FlutterError(code: "speech_recognizer_busy", message: nil, details: nil))
        return
      }
      startInFlight = true
      pendingStartResult = result
      let arguments = call.arguments as? [String: Any]
      authorizeAndStart(localeId: arguments?["localeId"] as? String, result: result)
    case "stop":
      // A permission prompt can outlive the Flutter route. Mark the pending
      // start as cancelled before tearing down audio so its completion block
      // cannot create an engine after the user has left the screen.
      finishPendingStart(nil)
      stop(cancel: false)
      result(nil)
    case "cancel":
      finishPendingStart(nil)
      stop(cancel: true)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func authorizeAndStart(localeId: String?, result: @escaping FlutterResult) {
    SFSpeechRecognizer.requestAuthorization { [weak self] speechStatus in
      guard let self, self.startInFlight else { return }
      guard speechStatus == .authorized else {
        self.fail("speech_permission_denied", result: result)
        return
      }
      self.requestMicrophonePermission { [weak self] granted in
        guard let self, self.startInFlight else { return }
        guard granted else {
          self.fail("microphone_permission_denied", result: result)
          return
        }
        DispatchQueue.main.async {
          guard self.startInFlight else { return }
          self.start(localeId: localeId, result: result)
        }
      }
    }
  }

  private func requestMicrophonePermission(
    completion: @escaping (Bool) -> Void
  ) {
    if #available(iOS 17.0, *) {
      AVAudioApplication.requestRecordPermission(completionHandler: completion)
    } else {
      AVAudioSession.sharedInstance().requestRecordPermission(completion)
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
    audioEngine = engine
    recognitionRequest = request
    let session = AVAudioSession.sharedInstance()

    // The input format is not valid until the recording session is active.
    // Reading it before activation can trigger Apple's fatal
    // `IsFormatSampleRateAndChannelCountValid` assertion on real devices.
    do {
      try session.setCategory(
        .playAndRecord,
        mode: .measurement,
        options: [.duckOthers, .allowBluetooth, .defaultToSpeaker]
      )
      try session.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      stop(cancel: true)
      fail("audio_session_unavailable", result: result)
      return
    }

    // AVAudioEngine can terminate the process with an assertion when a
    // device has no active input route (for example while another native
    // sheet is still releasing the microphone). Check the route before
    // touching inputNode's format so the Dart side receives a recoverable
    // error instead of an iOS crash.
    guard session.recordPermission == .granted,
          session.isInputAvailable,
          session.inputNumberOfChannels > 0 else {
      stop(cancel: true)
      fail("audio_input_unavailable", result: result)
      return
    }

    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0, format.channelCount > 0 else {
      stop(cancel: true)
      fail("audio_input_unavailable", result: result)
      return
    }
    input.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
      request.append(buffer)
    }
    inputTapInstalled = true

    do {
      engine.prepare()
      try engine.start()
    } catch {
      stop(cancel: true)
      fail("audio_session_unavailable", result: result)
      return
    }

    recognitionTask = recognizer.recognitionTask(with: request) { [weak self] response, error in
      // Recognition callbacks are not guaranteed to arrive on the main
      // thread. Serializing them prevents an old task from tearing down a
      // newer engine and avoids concurrent AVAudioEngine mutations.
      DispatchQueue.main.async { [weak self] in
        guard let self, self.recognitionRequest === request else { return }
        if let response {
          self.eventSink?([
            "type": "result",
            "words": response.bestTranscription.formattedString,
            "final": response.isFinal,
            "localeId": locale.identifier,
          ])
          if response.isFinal {
            self.stop(cancel: false)
            return
          }
        }
        if error != nil {
          self.eventSink?([
            "type": "error",
            "code": response == nil ? "speech_no_match" : "recognizer_error",
          ])
          self.stop(cancel: true)
        }
      }
    }
    eventSink?(["type": "status", "listening": true])
    finishPendingStart(nil)
  }

  private func fail(_ code: String, result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self, self.pendingStartResult != nil else { return }
      self.eventSink?(["type": "error", "code": code])
      self.finishPendingStart(
        FlutterError(code: code, message: nil, details: nil)
      )
    }
  }

  /// Completes the asynchronous `listen` method exactly once. In particular,
  /// route disposal may send `cancel` while an iOS permission sheet is still
  /// open; leaving the original FlutterResult unresolved would strand the
  /// Dart Future and make the next microphone attempt appear frozen.
  private func finishPendingStart(_ value: Any?) {
    startInFlight = false
    let completion = pendingStartResult
    pendingStartResult = nil
    completion?(value)
  }

  private func stop(cancel: Bool) {
    guard Thread.isMainThread else {
      // Flutter normally invokes method channels on the main thread, but a
      // recognizer callback can arrive elsewhere. Complete teardown
      // synchronously so a follow-up tap cannot race the old audio engine.
      DispatchQueue.main.sync { [weak self] in self?.stop(cancel: cancel) }
      return
    }
    let engine = audioEngine
    let request = recognitionRequest
    let task = recognitionTask
    audioEngine = nil
    recognitionRequest = nil
    recognitionTask = nil
    let tapWasInstalled = inputTapInstalled
    inputTapInstalled = false

    engine?.stop()
    if tapWasInstalled {
      engine?.inputNode.removeTap(onBus: 0)
    }
    request?.endAudio()
    if cancel { task?.cancel() } else { task?.finish() }
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
