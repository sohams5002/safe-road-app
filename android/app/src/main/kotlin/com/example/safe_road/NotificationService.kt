package com.example.safe_road

import android.os.Bundle
import android.provider.Settings
import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import io.flutter.plugin.common.EventChannel

class NotificationService : NotificationListenerService() {

    companion object {
        var eventSink: EventChannel.EventSink? = null

        fun isEnabled(context: Context): Boolean {
            val enabledListeners = Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners"
            )
            return enabledListeners?.contains(context.packageName) ?: false
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            val extras: Bundle = sbn.notification.extras
            val title = extras.get("android.title")?.toString() ?: ""
            val text = extras.get("android.text")?.toString() ?: ""

            val payload = mapOf(
                "type" to "notification",
                "package" to sbn.packageName,
                "title" to title,
                "text" to text,
                "time" to System.currentTimeMillis()
            )

            eventSink?.success(payload)

        } catch (e: Exception) {
            Log.e("NOTIF_SERVICE", "Error in onNotificationPosted: ${e.message}")
        }
    }
}
