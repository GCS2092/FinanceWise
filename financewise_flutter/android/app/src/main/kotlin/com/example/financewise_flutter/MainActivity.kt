package com.example.financewise_flutter

import android.content.Context
import android.content.Intent
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.example.financewise_flutter/sms"
    private val TAG = "MainActivity"
    private val SMS_PERMISSION_CODE = 1001

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Demander les permissions SMS au démarrage
        requestSmsPermission()
        
        // Vérifier s'il y a des données SMS en attente dans l'intent
        checkPendingSmsInIntent(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        checkPendingSmsInIntent(intent)
    }
    
    private fun checkPendingSmsInIntent(intent: Intent?) {
        intent?.let {
            val sender = it.getStringExtra("pending_sms_sender")
            val body = it.getStringExtra("pending_sms_body")
            val userChoice = it.getBooleanExtra("pending_sms_user_choice", false)
            val timestamp = it.getLongExtra("pending_sms_timestamp", 0L)
            
            if (sender != null && body != null && userChoice) {
                Log.d(TAG, "Found pending SMS in intent: $sender")
                
                // Stocker dans SharedPreferences natif pour compatibilité
                val prefs = getSharedPreferences("pending_sms", Context.MODE_PRIVATE)
                val editor = prefs.edit()
                editor.putString("sender", sender)
                editor.putString("body", body)
                editor.putLong("timestamp", timestamp)
                editor.putBoolean("user_choice", userChoice)
                editor.apply()
                
                Log.d(TAG, "SMS data stored in native SharedPreferences")
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        // Connecter le MethodChannel au SmsReceiver
        SmsReceiver.setMethodChannel(methodChannel)

        // Connecter le MethodChannel au SmsActionReceiver
        SmsActionReceiver.setMethodChannel(methodChannel)
        
        // Handler pour les appels depuis Flutter
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestSmsPermission" -> {
                    requestSmsPermission()
                    result.success(true)
                }
                "checkSmsPermission" -> {
                    val hasPermission = checkSmsPermission()
                    result.success(hasPermission)
                }
                "getPendingSms" -> {
                    val prefs = getSharedPreferences("pending_sms", Context.MODE_PRIVATE)
                    val sender = prefs.getString("sender", null)
                    val body = prefs.getString("body", null)
                    val timestamp = prefs.getLong("timestamp", 0L)
                    val userChoice = prefs.getBoolean("user_choice", false)
                    
                    Log.d(TAG, "getPendingSms called: sender=$sender, body=$body, userChoice=$userChoice")
                    
                    if (sender != null && body != null) {
                        result.success(mapOf(
                            "sender" to sender,
                            "body" to body,
                            "timestamp" to timestamp,
                            "user_choice" to userChoice
                        ))
                    } else {
                        result.success(null)
                    }
                }
                "clearPendingSms" -> {
                    val prefs = getSharedPreferences("pending_sms", Context.MODE_PRIVATE)
                    prefs.edit().clear().apply()
                    Log.d(TAG, "Pending SMS cleared")
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun checkSmsPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun requestSmsPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!checkSmsPermission()) {
                Log.d(TAG, "Requesting SMS permissions")
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(
                        Manifest.permission.RECEIVE_SMS,
                        Manifest.permission.READ_SMS
                    ),
                    SMS_PERMISSION_CODE
                )
            } else {
                Log.d(TAG, "SMS permissions already granted")
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_CODE) {
            if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                Log.d(TAG, "SMS permissions granted")
            } else {
                Log.d(TAG, "SMS permissions denied")
            }
        }
    }
}
