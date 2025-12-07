package com.example.safe_road

import android.content.ContentResolver
import android.database.Cursor
import android.net.Uri
import io.flutter.plugin.common.EventChannel

class SmsReader {

    companion object {

        var eventSink: EventChannel.EventSink? = null

        fun readSMS(contentResolver: ContentResolver) {
            val cursor: Cursor? = contentResolver.query(
                Uri.parse("content://sms/inbox"),
                null,
                null,
                null,
                "date DESC"
            )

            cursor?.let {
                while (cursor.moveToNext()) {

                    val sms = mapOf(
                        "type" to "sms",
                        "address" to cursor.getString(cursor.getColumnIndexOrThrow("address")),
                        "body" to cursor.getString(cursor.getColumnIndexOrThrow("body")),
                        "date" to cursor.getString(cursor.getColumnIndexOrThrow("date"))
                    )

                    eventSink?.success(sms)
                }
                cursor.close()
            }
        }
    }
}
