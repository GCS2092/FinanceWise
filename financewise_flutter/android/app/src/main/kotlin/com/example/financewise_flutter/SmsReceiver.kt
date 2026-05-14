package com.example.financewise_flutter

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsMessage
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel

class SmsReceiver : BroadcastReceiver() {
    companion object {
        private var methodChannel: MethodChannel? = null
        private const val CHANNEL_ID = "sms_detection_channel"
        const val NOTIFICATION_ID = 1001
        private const val TAG = "FinanceWise/SmsReceiver"

        fun setMethodChannel(channel: MethodChannel?) {
            methodChannel = channel
            Log.i(TAG, "[SMS_CHANNEL] MethodChannel ${if (channel != null) "attached" else "cleared"}")
        }

        fun invokeOnMain(runnable: Runnable) {
            android.os.Handler(android.os.Looper.getMainLooper()).post(runnable)
        }

        /**
         * Banque / mobile money : persiste comme un SMS et notifie Flutter si le moteur est prêt
         * (NotificationListenerService).
         */
        fun relayBankNotification(context: Context, packageName: String, combinedText: String) {
            val prefs = context.getSharedPreferences("pending_sms", Context.MODE_PRIVATE)
            prefs.edit()
                .putString("sender", packageName)
                .putString("body", combinedText)
                .putLong("timestamp", System.currentTimeMillis())
                .putBoolean("user_choice", false)
                .putBoolean("from_notification_listener", true)
                .apply()
            Log.i(TAG, "[NOTIFICATION_DETECTED] relayBankNotification pkg=$packageName len=${combinedText.length}")

            val payload = mapOf(
                "sender" to packageName,
                "body" to combinedText,
                "timestamp" to System.currentTimeMillis(),
            )
            val ch = methodChannel
            if (ch != null) {
                invokeOnMain {
                    try {
                        ch.invokeMethod("onBankNotification", payload)
                        Log.i(TAG, "[SMS_SENT_TO_FLUTTER] onBankNotification (from NL)")
                    } catch (e: Exception) {
                        Log.e(TAG, "[SMS_SENT_TO_FLUTTER] onBankNotification failed: ${e.message}", e)
                    }
                }
            } else {
                Log.w(TAG, "[SMS_SENT_TO_FLUTTER] onBankNotification deferred — prefs only, channel null")
            }
        }
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        val action = intent?.action
        Log.i(TAG, "[SMS_RECEIVED] onReceive action=$action")

        if (context == null || intent == null) {
            Log.w(TAG, "[SMS_RECEIVED] context or intent null — abort")
            return
        }

        if (ContextCompat.checkSelfPermission(context, android.Manifest.permission.RECEIVE_SMS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            Log.e(TAG, "[SMS_RECEIVED] RECEIVE_SMS not granted — cannot read SMS on this device")
            return
        }

        if (action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            Log.d(TAG, "[SMS_RECEIVED] ignored non-SMS action")
            return
        }

        try {
            val messages = readSmsMessages(intent)
            Log.i(TAG, "[SMS_PARSED] parts=${messages.size}")

            if (messages.isEmpty()) {
                Log.w(TAG, "[SMS_PARSED] no PDU / messages extracted")
                return
            }

            val aggregated = aggregateMultipart(messages)
            val sender = aggregated.first
            val body = aggregated.second

            Log.i(TAG, "[SMS_PARSED] sender=$sender bodyLength=${body.length}")
            if (body.isNotEmpty()) {
                Log.d(TAG, "[SMS_PARSED] bodyPreview=${body.take(160)}")
            }

            if (!isTransactionSms(sender, body)) {
                Log.d(TAG, "[TRANSACTION_DETECTED] false — filtered out")
                return
            }

            Log.i(TAG, "[TRANSACTION_DETECTED] true")

            createNotification(context, sender, body)
            storeSmsData(context, sender, body)

            val payload = mapOf(
                "sender" to sender,
                "body" to body,
                "timestamp" to System.currentTimeMillis(),
            )

            val ch = methodChannel
            if (ch != null) {
                invokeOnMain {
                    try {
                        ch.invokeMethod("onSmsReceived", payload)
                        Log.i(TAG, "[SMS_SENT_TO_FLUTTER] onSmsReceived invoked (main thread)")
                    } catch (e: Exception) {
                        Log.e(TAG, "[SMS_SENT_TO_FLUTTER] invoke failed: ${e.message}", e)
                    }
                }
            } else {
                Log.w(
                    TAG,
                    "[SMS_SENT_TO_FLUTTER] skipped — MethodChannel null (Flutter engine not ready). Data in SharedPreferences.",
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "[SMS_RECEIVED] error: ${e.message}", e)
        }
    }

    private fun readSmsMessages(intent: Intent): Array<out SmsMessage?> {
        return try {
            Telephony.Sms.Intents.getMessagesFromIntent(intent)
        } catch (e: Exception) {
            Log.e(TAG, "[SMS_PARSED] getMessagesFromIntent failed: ${e.message}", e)
            emptyArray()
        }
    }

    /**
     * Concatène les segments multipart ; garde l’expéditeur du premier segment non vide.
     */
    private fun aggregateMultipart(messages: Array<out SmsMessage?>): Pair<String, String> {
        val bodyBuilder = StringBuilder()
        var sender = ""
        for (m in messages) {
            if (m == null) continue
            val addr = m.originatingAddress?.trim().orEmpty()
            if (addr.isNotEmpty() && sender.isEmpty()) sender = addr
            val part = m.messageBody.orEmpty()
            bodyBuilder.append(part)
        }
        return Pair(sender, bodyBuilder.toString())
    }

    private fun createNotification(context: Context, sender: String, body: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Détection SMS",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Notifications pour les transactions SMS détectées"
            }
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }

        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("pending_sms", true)
            putExtra("pending_sms_sender", sender)
            putExtra("pending_sms_body", body)
            putExtra("pending_sms_user_choice", false)
            putExtra("pending_sms_timestamp", System.currentTimeMillis())
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val addIntent = Intent(context, SmsActionReceiver::class.java).apply {
            action = "ACTION_ADD_TRANSACTION"
            putExtra("sender", sender)
            putExtra("body", body)
        }
        val addPendingIntent = PendingIntent.getBroadcast(
            context,
            1,
            addIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val dismissIntent = Intent(context, SmsActionReceiver::class.java).apply {
            action = "ACTION_DISMISS_TRANSACTION"
            putExtra("notification_id", NOTIFICATION_ID)
        }
        val dismissPendingIntent = PendingIntent.getBroadcast(
            context,
            2,
            dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("Transaction détectée")
            .setContentText("SMS de $sender — Appuyez pour traiter")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setOngoing(false)
            .setAutoCancel(false)
            .setContentIntent(pendingIntent)
            .addAction(android.R.drawable.ic_input_add, "Ajouter", addPendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Ignorer", dismissPendingIntent)
            .build()

        NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
    }

    private fun storeSmsData(context: Context, sender: String, body: String) {
        val prefs = context.getSharedPreferences("pending_sms", Context.MODE_PRIVATE)
        prefs.edit()
            .putString("sender", sender)
            .putString("body", body)
            .putLong("timestamp", System.currentTimeMillis())
            .putBoolean("user_choice", false)
            .putBoolean("from_notification_listener", false)
            .apply()
        Log.d(TAG, "[OFFLINE_QUEUE] pending_sms prefs updated (user_choice=false)")
    }

    private fun isTransactionSms(sender: String, body: String): Boolean {
        val lowerSender = sender.lowercase()
        val lowerBody = body.lowercase()

        if (lowerSender.contains("wave") || lowerBody.contains("wave")) return true
        if (lowerSender.contains("orange") || lowerBody.contains("orange money") || lowerBody.contains("orangemoney")) return true
        if (lowerSender.contains("yango") || lowerBody.contains("yango") ||
            lowerSender.contains("taxi") || lowerBody.contains("taxi") ||
            lowerSender.contains("bolt") || lowerBody.contains("bolt") ||
            lowerSender.contains("uber") || lowerBody.contains("uber")
        ) {
            return true
        }
        if (lowerSender.contains("free") || lowerBody.contains("free money") ||
            lowerSender.contains("expresso") || lowerBody.contains("expresso") ||
            lowerSender.contains("wari") || lowerBody.contains("wari") ||
            lowerSender.contains("jonah") || lowerBody.contains("jonah")
        ) {
            return true
        }
        if (lowerBody.contains("fcfa") || lowerBody.contains("xof") ||
            lowerBody.contains("reçu") || lowerBody.contains("recu") ||
            lowerBody.contains("envoyé") || lowerBody.contains("envoye") ||
            lowerBody.contains("paiement") || lowerBody.contains("transfert")
        ) {
            return true
        }
        return false
    }
}
