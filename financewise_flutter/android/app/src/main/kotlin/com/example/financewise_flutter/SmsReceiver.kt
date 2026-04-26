package com.example.financewise_flutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsMessage
import io.flutter.plugin.common.MethodChannel

class SmsReceiver : BroadcastReceiver() {
    companion object {
        private var methodChannel: MethodChannel? = null
        
        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
        }
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            
            for (message in messages) {
                val sender = message.originatingAddress ?: ""
                val body = message.messageBody ?: ""
                
                // Détecter si c'est un SMS de Wave ou Orange Money
                if (isTransactionSms(sender, body)) {
                    val smsData = mapOf(
                        "sender" to sender,
                        "body" to body,
                        "timestamp" to System.currentTimeMillis()
                    )
                    
                    // Envoyer à Flutter via MethodChannel
                    methodChannel?.invokeMethod("onSmsReceived", smsData)
                }
            }
        }
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
