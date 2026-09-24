package com.bilhealth.bodyintelligencelog

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class BILFirebaseMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putString(LATEST_TOKEN, token)
            .apply()
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val deepLink = message.data[DEEP_LINK_KEY]
            ?.trim()
            ?.takeIf(::isSafeDeepLink)
            ?: return
        val title = message.notification?.title ?: message.data["title"] ?: "BIL"
        val body = message.notification?.body ?: message.data["body"] ?: return
        ensureChannel()
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(MainActivity.REMOTE_PUSH_DEEP_LINK_EXTRA, deepLink)
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            deepLink.hashCode(),
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title.take(MAX_TEXT_LENGTH))
            .setContentText(body.take(MAX_TEXT_LENGTH))
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(message.messageId?.hashCode() ?: deepLink.hashCode(), notification)
    }

    private fun isSafeDeepLink(value: String): Boolean =
        value.length <= MainActivity.MAX_PUSH_PAYLOAD_LENGTH &&
            runCatching { android.net.Uri.parse(value).scheme.equals("bil", true) }
                .getOrDefault(false)

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "BIL updates",
                NotificationManager.IMPORTANCE_DEFAULT,
            ),
        )
    }

    private companion object {
        const val CHANNEL_ID = "bil_remote_updates"
        const val DEEP_LINK_KEY = "deep_link"
        const val MAX_TEXT_LENGTH = 180
        const val PREFERENCES = "bil_fcm"
        const val LATEST_TOKEN = "latest_token"
    }
}
