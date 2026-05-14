package com.example.financewise_flutter

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

/**
 * Écoute les notifications d’apps financières (whitelist).
 * Complète le flux SMS : persistance + [onBankNotification] vers Flutter si prêt.
 *
 * L’utilisateur doit activer manuellement l’accès dans Réglages Android
 * (Notifications > accès aux notifications > FinanceWise).
 */
class TransactionNotificationListener : NotificationListenerService() {

    companion object {
        private const val TAG = "FinanceWise/NotifListener"

        /** Packages connus — étendre selon les marchés / mises à jour des apps. */
        private val WHITELIST_PACKAGES = setOf(
            "com.wave.personal",
            "sn.wave.personal",
            "com.orange.mobile.orangemoneyapp",
            "com.orange.mobile.orangemoney",
            "com.orange.orange_money",
            "com.orange.myorange",
            "com.wiz.orange_money_sn",
            "com.afm.wallet",
            "com.paypal.android.p2pmobile",
            "com.android.bank",
        )
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.i(TAG, "[NOTIFICATION_DETECTED] listener connected")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            val pkg = sbn.packageName ?: return
            if (pkg == applicationContext.packageName) {
                // Ignorer nos propres notifs SMS internes
                return
            }
            if (!WHITELIST_PACKAGES.contains(pkg)) {
                return
            }

            val extras = sbn.notification.extras
            val title = extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
            val text = extras?.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
            val big = extras?.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString().orEmpty()
            val combined = listOf(title, text, big).filter { it.isNotBlank() }.joinToString(" ").trim()
            if (combined.isEmpty()) {
                Log.d(TAG, "[NOTIFICATION_DETECTED] empty text pkg=$pkg")
                return
            }
            if (!looksLikeFinance(combined)) {
                Log.d(TAG, "[NOTIFICATION_DETECTED] filtered (no finance keywords) pkg=$pkg")
                return
            }

            Log.i(TAG, "[NOTIFICATION_DETECTED] pkg=$pkg preview=${combined.take(120)}")
            SmsReceiver.relayBankNotification(applicationContext, pkg, combined)
        } catch (e: Exception) {
            Log.e(TAG, "[NOTIFICATION_DETECTED] error: ${e.message}", e)
        }
    }

    private fun looksLikeFinance(text: String): Boolean {
        val t = text.lowercase()
        return t.contains("fcfa") || t.contains("xof") || t.contains("cfa") ||
            t.contains("wave") || t.contains("orange") || t.contains("money") ||
            t.contains("reçu") || t.contains("recu") || t.contains("envoyé") || t.contains("envoye") ||
            t.contains("paiement") || t.contains("transfert") || t.contains("débit") || t.contains("debit")
    }
}
