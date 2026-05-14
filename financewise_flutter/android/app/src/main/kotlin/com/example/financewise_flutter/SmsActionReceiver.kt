package com.example.financewise_flutter

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.plugin.common.MethodChannel

class SmsActionReceiver : BroadcastReceiver() {
    companion object {
        private var methodChannel: MethodChannel? = null
        private const val TAG = "FinanceWise/SmsActionReceiver"

        fun setMethodChannel(channel: MethodChannel?) {
            methodChannel = channel
            Log.i(TAG, "[SMS_CHANNEL] MethodChannel ${if (channel != null) "attached" else "cleared"}")
        }
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        context ?: run {
            Log.w(TAG, "[SMS_RECEIVED] context null")
            return
        }
        intent ?: run {
            Log.w(TAG, "[SMS_RECEIVED] intent null")
            return
        }

        val action = intent.action
        Log.i(TAG, "[SMS_RECEIVED] SmsActionReceiver action=$action")

        when (action) {
            "ACTION_ADD_TRANSACTION" -> {
                val sender = intent.getStringExtra("sender").orEmpty()
                val body = intent.getStringExtra("body").orEmpty()
                Log.i(TAG, "[TRANSACTION_DETECTED] add action sender=$sender bodyLen=${body.length}")

                val prefs = context.getSharedPreferences("pending_sms", Context.MODE_PRIVATE)
                prefs.edit()
                    .putString("sender", sender)
                    .putString("body", body)
                    .putLong("timestamp", System.currentTimeMillis())
                    .putBoolean("user_choice", true)
                    .apply()
                Log.d(TAG, "[OFFLINE_QUEUE] pending_sms stored user_choice=true")

                val appIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("pending_sms_sender", sender)
                    putExtra("pending_sms_body", body)
                    putExtra("pending_sms_user_choice", true)
                    putExtra("pending_sms_timestamp", System.currentTimeMillis())
                }
                try {
                    context.startActivity(appIntent)
                    Log.i(TAG, "[SMS_SENT_TO_FLUTTER] Activity launched with pending SMS extras")
                } catch (e: Exception) {
                    Log.e(TAG, "[SMS_SENT_TO_FLUTTER] startActivity failed: ${e.message}", e)
                }

                val ch = methodChannel
                if (ch != null) {
                    SmsReceiver.invokeOnMain {
                        try {
                            ch.invokeMethod(
                                "onSmsActionAdd",
                                mapOf(
                                    "sender" to sender,
                                    "body" to body,
                                    "timestamp" to System.currentTimeMillis(),
                                ),
                                object : MethodChannel.Result {
                                    override fun success(result: Any?) {
                                        Log.i(TAG, "[SMS_SENT_TO_FLUTTER] onSmsActionAdd success: $result")
                                    }

                                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                                        Log.e(TAG, "[SMS_SENT_TO_FLUTTER] onSmsActionAdd error: $errorCode $errorMessage")
                                    }

                                    override fun notImplemented() {
                                        Log.w(TAG, "[SMS_SENT_TO_FLUTTER] onSmsActionAdd notImplemented in Dart")
                                    }
                                },
                            )
                        } catch (e: Exception) {
                            Log.e(TAG, "[SMS_SENT_TO_FLUTTER] invokeMethod exception: ${e.message}", e)
                        }
                    }
                } else {
                    Log.w(TAG, "[SMS_SENT_TO_FLUTTER] MethodChannel null — Flutter will read SharedPreferences on resume")
                }

                cancelNotification(context)
            }

            "ACTION_DISMISS_TRANSACTION" -> {
                val prefs = context.getSharedPreferences("pending_sms", Context.MODE_PRIVATE)
                prefs.edit().clear().apply()
                Log.i(TAG, "[OFFLINE_QUEUE] pending_sms cleared (dismiss)")
                cancelNotification(context)
            }
        }
    }

    private fun cancelNotification(context: Context) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(SmsReceiver.NOTIFICATION_ID)
        Log.d(TAG, "Notification cancelled id=${SmsReceiver.NOTIFICATION_ID}")
    }
}
