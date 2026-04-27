package com.example.financewise_flutter

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.MethodChannel

class SmsReceiver : BroadcastReceiver() {
    companion object {
        private var methodChannel: MethodChannel? = null
        private const val CHANNEL_ID = "sms_detection_channel"
        private const val NOTIFICATION_ID = 1001
        private const val TAG = "SmsReceiver"
        
        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
            Log.d(TAG, "MethodChannel set")
        }
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        Log.d(TAG, "onReceive called with action: ${intent?.action}")
        
        if (intent?.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            Log.d(TAG, "Received ${messages.size} SMS messages")
            
            for (message in messages) {
                val sender = message.originatingAddress ?: ""
                val body = message.messageBody ?: ""
                
                Log.d(TAG, "SMS from: $sender, body: $body")
                
                // Détecter si c'est un SMS de Wave ou Orange Money
                if (isTransactionSms(sender, body)) {
                    Log.d(TAG, "Transaction SMS detected!")
                    
                    // Créer une notification
                    createNotification(context, sender, body)
                    
                    // Stocker les données SMS pour utilisation ultérieure
                    storeSmsData(context, sender, body)
                    
                    // Envoyer à Flutter si l'app est ouverte
                    methodChannel?.invokeMethod("onSmsReceived", mapOf(
                        "sender" to sender,
                        "body" to body,
                        "timestamp" to System.currentTimeMillis()
                    ))
                    Log.d(TAG, "Sent to Flutter via MethodChannel")
                } else {
                    Log.d(TAG, "Not a transaction SMS")
                }
            }
        }
    }

    private fun createNotification(context: Context?, sender: String, body: String) {
        context ?: return
        
        // Créer le canal de notification (nécessaire pour Android 8+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Détection SMS",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications pour les transactions SMS détectées"
            }
            
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
        
        // Créer l'intent pour ouvrir l'app quand on clique sur la notification
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("pending_sms", true)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Créer la notification
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("Transaction détectée")
            .setContentText("SMS de $sender - Cliquez pour ajouter")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()
        
        // Afficher la notification
        val notificationManager = NotificationManagerCompat.from(context)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    private fun storeSmsData(context: Context?, sender: String, body: String) {
        context ?: return
        
        val prefs = context.getSharedPreferences("pending_sms", Context.MODE_PRIVATE)
        val editor = prefs.edit()
        editor.putString("sender", sender)
        editor.putString("body", body)
        editor.putLong("timestamp", System.currentTimeMillis())
        editor.apply()
    }

    private fun isTransactionSms(sender: String, body: String): Boolean {
        val lowerSender = sender.lowercase()
        val lowerBody = body.lowercase()
        
        // Détecter Wave
        if (lowerSender.contains("wave") || lowerBody.contains("wave")) {
            return true
        }
        
        // Détecter Orange Money
        if (lowerSender.contains("orange") || lowerBody.contains("orange money")) {
            return true
        }
        
        // Détecter patterns de transaction (montants, FCFA, XOF)
        if (lowerBody.contains("fcfa") || lowerBody.contains("xof") || 
            lowerBody.contains("reçu") || lowerBody.contains("envoyé")) {
            return true
        }
        
        return false
    }
}
