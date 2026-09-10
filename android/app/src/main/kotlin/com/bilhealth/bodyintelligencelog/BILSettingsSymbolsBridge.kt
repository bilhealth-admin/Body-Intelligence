package com.bilhealth.bodyintelligencelog

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.util.LruCache
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.DrawableCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/** Google's Material Symbols VectorDrawables, drawn locally and cached. */
object BILSettingsSymbolsBridge {
    private val cache = LruCache<String, ByteArray>(72)
    private val symbols = mapOf(
        "profile" to R.drawable.bil_symbol_profile, "camera" to R.drawable.bil_symbol_camera,
        "email" to R.drawable.bil_symbol_email, "height" to R.drawable.bil_symbol_height,
        "people" to R.drawable.bil_symbol_people, "calendar" to R.drawable.bil_symbol_calendar,
        "location" to R.drawable.bil_symbol_location, "postal" to R.drawable.bil_symbol_postal,
        "time" to R.drawable.bil_symbol_time, "measure" to R.drawable.bil_symbol_measure,
        "nutrition" to R.drawable.bil_symbol_nutrition, "goals" to R.drawable.bil_symbol_goals,
        "preferences" to R.drawable.bil_symbol_preferences, "language" to R.drawable.bil_symbol_language,
        "appearance" to R.drawable.bil_symbol_appearance, "privacy" to R.drawable.bil_symbol_privacy,
        "exercise" to R.drawable.bil_symbol_exercise, "notifications" to R.drawable.bil_symbol_notifications,
        "health" to R.drawable.bil_symbol_health, "cloud" to R.drawable.bil_symbol_cloud,
        "support" to R.drawable.bil_symbol_support, "moderation" to R.drawable.bil_symbol_moderation,
        "weight" to R.drawable.bil_symbol_weight,
        "foodSearch" to R.drawable.bil_symbol_food_search,
        "barcode" to R.drawable.bil_symbol_barcode,
        "voice" to R.drawable.bil_symbol_voice,
        "notes" to R.drawable.bil_symbol_notes,
        "water" to R.drawable.bil_symbol_water,
        "breakfast" to R.drawable.bil_symbol_breakfast,
        "lunch" to R.drawable.bil_symbol_lunch,
        "dinner" to R.drawable.bil_symbol_dinner,
        "snack" to R.drawable.bil_symbol_snack,
        "progress" to R.drawable.bil_symbol_progress,
        "report" to R.drawable.bil_symbol_report,
        "challenges" to R.drawable.bil_symbol_challenges,
        "recipes" to R.drawable.bil_symbol_recipes,
        "fasting" to R.drawable.bil_symbol_fasting,
        "sleep" to R.drawable.bil_symbol_sleep,
        "devices" to R.drawable.bil_symbol_devices,
        "learn" to R.drawable.bil_symbol_learn,
        "messages" to R.drawable.bil_symbol_messages,
        "aiCoach" to R.drawable.bil_symbol_ai_coach,
        "verifiedFood" to R.drawable.bil_symbol_verified_food,
        "export" to R.drawable.bil_symbol_export,
        "accountDeletion" to R.drawable.bil_symbol_account_deletion,
        "legal" to R.drawable.bil_symbol_legal,
        "heartRate" to R.drawable.bil_symbol_heart_rate,
        "distance" to R.drawable.bil_symbol_distance,
        "bodyFat" to R.drawable.bil_symbol_body_fat,
        "oxygen" to R.drawable.bil_symbol_oxygen,
        "dashboard" to R.drawable.bil_symbol_dashboard,
        "discover" to R.drawable.bil_symbol_discover,
        "more" to R.drawable.bil_symbol_more,
        "diary" to R.drawable.bil_symbol_diary,
    )

    fun register(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, "bil/settings_symbols").setMethodCallHandler { call, result ->
            if (call.method != "render") { result.notImplemented(); return@setMethodCallHandler }
            val symbol = call.argument<String>("symbol")
            val resource = symbols[symbol]
            val pixels = call.argument<Number>("pixels")?.toInt()?.coerceIn(16, 128)
            if (resource == null || pixels == null) {
                result.error("invalid_symbol", null, null); return@setMethodCallHandler
            }
            val key = "$symbol:$pixels"
            val cached = cache.get(key)
            if (cached != null) { result.success(cached); return@setMethodCallHandler }
            try {
                val drawable = ContextCompat.getDrawable(context, resource)?.mutate()
                if (drawable == null) { result.success(null); return@setMethodCallHandler }
                DrawableCompat.setTint(drawable, Color.WHITE)
                val bitmap = Bitmap.createBitmap(pixels, pixels, Bitmap.Config.ARGB_8888)
                val bytes = try {
                    drawable.setBounds(0, 0, pixels, pixels)
                    drawable.draw(Canvas(bitmap))
                    ByteArrayOutputStream().use { stream ->
                        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                        stream.toByteArray()
                    }
                } finally { bitmap.recycle() }
                cache.put(key, bytes)
                result.success(bytes)
            } catch (_: Exception) { result.success(null) }
        }
    }
}
