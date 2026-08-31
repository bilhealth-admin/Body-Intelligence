package com.bilhealth.bodyintelligencelog

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/** AES-256-GCM backed exclusively by Android's installed JCA provider. */
class BILSystemCryptoBridge(messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val secureRandom = SecureRandom()

    init {
        channel.setMethodCallHandler(::handle)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "encryptAes256Gcm" -> encrypt(call, result)
                "decryptAes256Gcm" -> decrypt(call, result)
                else -> result.notImplemented()
            }
        } catch (_: Exception) {
            // Fail closed without returning key, plaintext or provider details.
            result.error(
                "system_crypto_failed",
                "System AES-GCM operation failed.",
                null,
            )
        }
    }

    private fun encrypt(call: MethodCall, result: MethodChannel.Result) {
        val keyBytes = requiredBytes(call, "key")
        val plaintext = requiredBytes(call, "plaintext")
        require(keyBytes.size == KEY_LENGTH_BYTES)

        val nonce = ByteArray(NONCE_LENGTH_BYTES).also(secureRandom::nextBytes)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(
            Cipher.ENCRYPT_MODE,
            SecretKeySpec(keyBytes, "AES"),
            GCMParameterSpec(TAG_LENGTH_BITS, nonce),
        )
        // JCA returns ciphertext followed by the 128-bit GCM authentication tag.
        val protectedBytes = cipher.doFinal(plaintext)
        result.success(mapOf("nonce" to nonce, "protected" to protectedBytes))
    }

    private fun decrypt(call: MethodCall, result: MethodChannel.Result) {
        val keyBytes = requiredBytes(call, "key")
        val nonce = requiredBytes(call, "nonce")
        val protectedBytes = requiredBytes(call, "protected")
        require(keyBytes.size == KEY_LENGTH_BYTES)
        require(nonce.size == NONCE_LENGTH_BYTES)
        require(protectedBytes.size >= TAG_LENGTH_BYTES)

        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(
            Cipher.DECRYPT_MODE,
            SecretKeySpec(keyBytes, "AES"),
            GCMParameterSpec(TAG_LENGTH_BITS, nonce),
        )
        result.success(cipher.doFinal(protectedBytes))
    }

    private fun requiredBytes(call: MethodCall, name: String): ByteArray =
        requireNotNull(call.argument<ByteArray>(name))

    companion object {
        private const val CHANNEL = "bil/system_crypto"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val KEY_LENGTH_BYTES = 32
        private const val NONCE_LENGTH_BYTES = 12
        private const val TAG_LENGTH_BYTES = 16
        private const val TAG_LENGTH_BITS = TAG_LENGTH_BYTES * 8
    }
}
