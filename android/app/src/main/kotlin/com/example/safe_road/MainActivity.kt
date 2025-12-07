package com.example.safe_road

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "open_settings"
    private val EVENT_CHANNEL = "notification_stream"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // -------------------------------------------------------------
        // METHOD CHANNEL — Check / Open Notification Access
        // -------------------------------------------------------------
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // Check if Notification Access is enabled
                    "checkNotificationAccess" -> {
                        val enabled = NotificationService.isEnabled(this)
                        result.success(enabled)
                    }

                    // Open settings page
                    "openNotificationAccess" -> {
                        try {
                            val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR_OPENING_SETTINGS", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        // -------------------------------------------------------------
        // EVENT CHANNEL — Unified Notification + SMS + Call Stream
        // -------------------------------------------------------------
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {

                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    // Connect all sinks to same flutter stream
                    NotificationService.eventSink = events
                    SmsReader.eventSink = events
                    CallLogReader.eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    NotificationService.eventSink = null
                    SmsReader.eventSink = null
                    CallLogReader.eventSink = null
                }
            })
    }
}
