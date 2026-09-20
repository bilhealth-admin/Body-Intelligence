import AVFoundation
import Flutter

/// Plays the two local microphone affordance sounds.
final class BILMicSoundBridge: NSObject, AVAudioPlayerDelegate {
  private let channel: FlutterMethodChannel
  private var player: AVAudioPlayer?
  private var playbackResult: FlutterResult?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "bil/mic_sound", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let name: String
    switch call.method {
    case "playOpen": name = "bil_mic_open_vibration"
    case "playEnd": name = "bil_mic_end_vibration"
    default:
      result(FlutterMethodNotImplemented)
      return
    }

    guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
      result(FlutterError(code: "mic_sound_unavailable", message: nil, details: nil))
      return
    }
    do {
      player?.stop()
      finishPendingPlayback()
      let active = try AVAudioPlayer(contentsOf: url)
      active.delegate = self
      active.volume = 0.55
      active.prepareToPlay()
      player = active
      playbackResult = result
      guard active.play() else {
        player = nil
        finishPendingPlayback(
          FlutterError(code: "mic_sound_playback_rejected", message: nil, details: nil)
        )
        return
      }
    } catch {
      result(FlutterError(code: "mic_sound_failed", message: error.localizedDescription, details: nil))
    }
  }

  // Completing the MethodChannel call only after the 140 ms WAV finishes
  // makes Dart's `await BilMicSound.playOpen()` a real sequencing boundary:
  // the speech recognizer cannot open the microphone under the cue.
  func audioPlayerDidFinishPlaying(_ finishedPlayer: AVAudioPlayer, successfully flag: Bool) {
    guard player === finishedPlayer else { return }
    player = nil
    finishPendingPlayback(
      flag ? nil : FlutterError(code: "mic_sound_playback_failed", message: nil, details: nil)
    )
  }

  func audioPlayerDecodeErrorDidOccur(_ failedPlayer: AVAudioPlayer, error: Error?) {
    guard player === failedPlayer else { return }
    player = nil
    finishPendingPlayback(
      FlutterError(code: "mic_sound_failed", message: error?.localizedDescription, details: nil)
    )
  }

  private func finishPendingPlayback(_ error: FlutterError? = nil) {
    guard let callback = playbackResult else { return }
    playbackResult = nil
    if let error { callback(error) } else { callback(nil) }
  }

  func dispose() {
    player?.stop()
    player = nil
    finishPendingPlayback()
    channel.setMethodCallHandler(nil)
  }
}
