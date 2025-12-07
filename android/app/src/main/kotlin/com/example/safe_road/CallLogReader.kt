package com.example.safe_road

import android.content.ContentResolver
import android.provider.CallLog
import io.flutter.plugin.common.EventChannel

class CallLogReader {

    companion object {

        var eventSink: EventChannel.EventSink? = null

        fun readCallLogs(contentResolver: ContentResolver) {

            val cursor = contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                null,
                null,
                null,
                CallLog.Calls.DATE + " DESC"
            )

            cursor?.let {
                while (cursor.moveToNext()) {

                    val entry = mapOf(
                        "type" to "call",
                        "number" to cursor.getString(cursor.getColumnIndexOrThrow(CallLog.Calls.NUMBER)),
                        "call_type" to cursor.getString(cursor.getColumnIndexOrThrow(CallLog.Calls.TYPE)),
                        "duration" to cursor.getString(cursor.getColumnIndexOrThrow(CallLog.Calls.DURATION)),
                        "date" to cursor.getString(cursor.getColumnIndexOrThrow(CallLog.Calls.DATE))
                    )

                    eventSink?.success(entry)
                }

                cursor.close()
            }
        }
    }
}
