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
        private const val TAG = "SmsActionReceiver"

        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
            Log.d(TAG, "MethodChannel set")
        }
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        context ?: return
        intent ?: return

        val action = intent.action
        Log.d(TAG, "Received action: $action")

        when (action) {
            "ACTION_ADD_TRANSACTION" -> {
                // Stocker les données SMS pour traitement par Flutter
                val sender = intent.getStringExtra("sender") ?: ""
                val body = intent.getStringExtra("body") ?: ""

                val prefs = context.getSharedPreferences("pending_sms", Context.MODE_PRIVATE)
                val editor = prefs.edit()
                editor.putString("sender", sender)
                editor.putString("body", body)
                editor.putLong("timestamp", System.currentTimeMillis())
                editor.putBoolean("user_choice", true) // Utilisateur a choisi "Ajouter"
                editor.apply()

                Log.d(TAG, "SMS stored for Flutter processing: $sender")

                // Ouvrir l'application avec les données SMS dans l'intent
                val appIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("pending_sms_sender", sender)
                    putExtra("pending_sms_body", body)
                    putExtra("pending_sms_user_choice", true)
                    putExtra("pending_sms_timestamp", System.currentTimeMillis())
                }
                context.startActivity(appIntent)
                Log.d(TAG, "Application launched with SMS data in intent")

                // Envoyer à Flutter si l'app est ouverte
                Log.d(TAG, "Attempting to send to Flutter via MethodChannel")
                methodChannel?.let {
                    Log.d(TAG, "MethodChannel exists, invoking method")
                    it.invokeMethod("onSmsActionAdd", mapOf(
                        "sender" to sender,
                        "body" to body,
                        "timestamp" to System.currentTimeMillis()
                    ), object : MethodChannel.Result {
                        override fun success(result: Any?) {
                            Log.d(TAG, "MethodChannel call succeeded: $result")
                        }
                        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                            Log.e(TAG, "MethodChannel call failed: $errorCode - $errorMessage")
                        }
                        override fun notImplemented() {
                            Log.w(TAG, "MethodChannel method not implemented in Flutter")
                        }
                    })
                } ?: Log.w(TAG, "MethodChannel is null, cannot send to Flutter")

                // Annuler la notification
                cancelNotification(context)
            }

            "ACTION_DISMISS_TRANSACTION" -> {
                // L'utilisateur a choisi "Pas" - ne pas stocker le SMS
                val prefs = context.getSharedPreferences("pending_sms", Context.MODE_PRIVATE)
                val editor = prefs.edit()
                editor.clear()
                editor.apply()

                Log.d(TAG, "SMS dismissed by user")

                // Annuler la notification
                cancelNotification(context)
            }
        }
    }

    private fun cancelNotification(context: Context) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(SmsReceiver.NOTIFICATION_ID)
        Log.d(TAG, "Notification cancelled")
    }
}
