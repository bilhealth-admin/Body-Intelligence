import CryptoKit
import Flutter
import Foundation

/// AES-256-GCM backed exclusively by Apple CryptoKit.
final class BILSystemCryptoBridge {
  private static let channelName = "bil/system_crypto"
  private static let keyLength = 32
  private static let nonceLength = 12
  private static let tagLength = 16

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler(handle)
  }

  private static func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    do {
      switch call.method {
      case "encryptAes256Gcm":
        let arguments = try requiredArguments(call)
        let keyData = try requiredData(arguments, "key")
        let plaintext = try requiredData(arguments, "plaintext")
        guard keyData.count == keyLength else { throw CryptoBridgeError.invalidInput }

        let sealed = try AES.GCM.seal(
          plaintext,
          using: SymmetricKey(data: keyData)
        )
        let nonce = sealed.nonce.withUnsafeBytes { Data($0) }
        guard nonce.count == nonceLength else { throw CryptoBridgeError.invalidOutput }
        let protected = sealed.ciphertext + sealed.tag
        result([
          "nonce": FlutterStandardTypedData(bytes: nonce),
          "protected": FlutterStandardTypedData(bytes: protected),
        ])

      case "decryptAes256Gcm":
        let arguments = try requiredArguments(call)
        let keyData = try requiredData(arguments, "key")
        let nonceData = try requiredData(arguments, "nonce")
        let protected = try requiredData(arguments, "protected")
        guard keyData.count == keyLength,
              nonceData.count == nonceLength,
              protected.count >= tagLength else {
          throw CryptoBridgeError.invalidInput
        }

        let split = protected.count - tagLength
        let sealed = try AES.GCM.SealedBox(
          nonce: AES.GCM.Nonce(data: nonceData),
          ciphertext: protected.prefix(split),
          tag: protected.suffix(tagLength)
        )
        let plaintext = try AES.GCM.open(
          sealed,
          using: SymmetricKey(data: keyData)
        )
        result(FlutterStandardTypedData(bytes: plaintext))

      default:
        result(FlutterMethodNotImplemented)
      }
    } catch {
      // Fail closed without returning key, plaintext or CryptoKit details.
      result(FlutterError(
        code: "system_crypto_failed",
        message: "System AES-GCM operation failed.",
        details: nil
      ))
    }
  }

  private static func requiredArguments(
    _ call: FlutterMethodCall
  ) throws -> [String: Any] {
    guard let arguments = call.arguments as? [String: Any] else {
      throw CryptoBridgeError.invalidInput
    }
    return arguments
  }

  private static func requiredData(
    _ arguments: [String: Any],
    _ name: String
  ) throws -> Data {
    guard let value = arguments[name] as? FlutterStandardTypedData else {
      throw CryptoBridgeError.invalidInput
    }
    return value.data
  }

  private enum CryptoBridgeError: Error {
    case invalidInput
    case invalidOutput
  }
}
