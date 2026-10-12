package com.bilhealth.bodyintelligencelog

import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.nl.languageid.LanguageIdentification
import com.google.mlkit.nl.languageid.LanguageIdentifier
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.Translator
import com.google.mlkit.nl.translate.TranslatorOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Only model downloads/SDK diagnostics use the network; UGC stays on device.
 * One bounded job; callbacks from retired jobs never publish text. */
class BILCommunityTranslationBridge(messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "bil/community_translation")
    private var detector: LanguageIdentifier? = null
    private var activeId: String? = null
    private var activeResult: MethodChannel.Result? = null
    private var translator: Translator? = null
    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "cancel" -> {
                    if (call.argument<String>("requestId") == activeId) cancel()
                    result.success(null)
                }
                "translate" -> {
                    val id = call.argument<String>("requestId")
                    val texts = call.argument<Map<String, String>>("texts")
                    val tag = call.argument<String>("targetTag")
                    if (id.isNullOrEmpty() || texts.isNullOrEmpty() || texts.size > 2 ||
                        texts.values.any { it.length > 12000 } || tag == null) {
                        result.error("invalid_input", null, null)
                    } else if (activeId != null) {
                        result.error("translation_busy", null, null)
                    } else {
                        // ML Kit's Chinese model does not promise Traditional output.
                        val target = if (tag == "zh-Hant") null else
                            TranslateLanguage.fromLanguageTag(tag.substringBefore('-'))
                        if (target == null) result.error("language_unavailable", null, null)
                        else {
                            activeId = id; activeResult = result
                            translateNext(id, texts.entries.toList(), target, 0, linkedMapOf(), false)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    private fun translateNext(id: String, entries: List<Map.Entry<String, String>>,
        target: String, index: Int, output: LinkedHashMap<String, String>, changed: Boolean) {
        if (activeId != id) return
        if (index == entries.size) {
            finish(id, mapOf("texts" to output, "engine" to "google", "sameLanguage" to !changed))
            return
        }
        val entry = entries[index]
        if (entry.value.isBlank()) {
            output[entry.key] = entry.value
            translateNext(id, entries, target, index + 1, output, changed)
            return
        }
        val identifier = detector ?: LanguageIdentification.getClient().also { detector = it }
        identifier.identifyLanguage(entry.value).addOnSuccessListener { detected ->
            if (activeId != id) return@addOnSuccessListener
            val source = TranslateLanguage.fromLanguageTag(detected)
            if (source == null || detected == "und") { fail(id, "language_unavailable"); return@addOnSuccessListener }
            if (source == target) {
                output[entry.key] = entry.value
                translateNext(id, entries, target, index + 1, output, changed)
                return@addOnSuccessListener
            }
            translator?.close()
            val client = Translation.getClient(TranslatorOptions.Builder()
                .setSourceLanguage(source).setTargetLanguage(target).build())
            translator = client
            client.downloadModelIfNeeded(DownloadConditions.Builder().requireWifi().build())
                .addOnSuccessListener download@{
                    if (activeId != id) return@download
                    client.translate(entry.value).addOnSuccessListener translate@{ translated ->
                        if (activeId != id) return@translate
                        output[entry.key] = translated
                        translateNext(id, entries, target, index + 1, output, true)
                    }.addOnFailureListener { fail(id, "translation_failed") }
                }.addOnFailureListener { fail(id, "model_unavailable") }
        }.addOnFailureListener { fail(id, "language_unavailable") }
    }
    private fun finish(id: String, value: Any) {
        if (activeId != id) return
        val result = activeResult
        activeResult = null; activeId = null
        translator?.close(); translator = null
        result?.success(value)
    }
    private fun fail(id: String, code: String) {
        if (activeId != id) return
        val result = activeResult
        activeResult = null; activeId = null
        translator?.close(); translator = null
        result?.error(code, null, null)
    }
    private fun cancel() { activeId?.let { fail(it, "translation_cancelled") } }
    fun stopForBackground() { cancel() }
    fun dispose() { cancel(); detector?.close(); detector = null; channel.setMethodCallHandler(null) }
}
