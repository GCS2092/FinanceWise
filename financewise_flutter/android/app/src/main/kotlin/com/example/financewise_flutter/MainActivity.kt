package com.example.financewise_flutter

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.example.financewise_flutter/sms"
    private val tag = "FinanceWise/MainActivity"
    private val smsPermissionCode = 1001
    private val notificationPermissionCode = 1002

    private var smsMethodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        Log.i(tag, "[SMS_RECEIVED] MainActivity onCreate")
        requestSmsPermissionIfNeeded()
        requestPostNotificationsIfNeeded()
        checkPendingSmsInIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        Log.i(tag, "[SMS_RECEIVED] onNewIntent extras=${intent.extras?.keySet()}")
        checkPendingSmsInIntent(intent)
    }

    private fun checkPendingSmsInIntent(intent: Intent?) {
        intent ?: return

        val sender = intent.getStringExtra("pending_sms_sender")
        val body = intent.getStringExtra("pending_sms_body")
        val userChoice = intent.getBooleanExtra("pending_sms_user_choice", false)
        val timestamp = intent.getLongExtra("pending_sms_timestamp", 0L)
        val pendingFlag = intent.getBooleanExtra("pending_sms", false)

        if (sender != null && body != null) {
            Log.i(tag, "[SMS_PARSED] Intent pending SMS sender=$sender userChoice=$userChoice")
            val prefs = getSharedPreferences("pending_sms", Context.MODE_PRIVATE)
            val ed = prefs.edit()
                .putString("sender", sender)
                .putString("body", body)
                .putLong("timestamp", if (timestamp > 0L) timestamp else System.currentTimeMillis())
                .putBoolean("user_choice", userChoice)
            if (pendingFlag) {
                ed.putBoolean("opened_from_tap", true)
            }
            ed.apply()
            Log.d(tag, "[OFFLINE_QUEUE] pending_sms synced from intent")
        } else if (pendingFlag) {
            Log.d(tag, "[SMS_PARSED] pending_sms flag without extras — prefs inchangées (déjà remplies par SmsReceiver)")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        smsMethodChannel = methodChannel

        SmsReceiver.setMethodChannel(methodChannel)
        SmsActionReceiver.setMethodChannel(methodChannel)

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestSmsPermission" -> {
                    requestSmsPermissionIfNeeded()
                    result.success(true)
                }
                "checkSmsPermission" -> {
                    result.success(checkSmsPermission())
                }
                "requestNotificationPermission" -> {
                    requestPostNotificationsIfNeeded()
                    result.success(true)
                }
                "checkNotificationPermission" -> {
                    result.success(checkNotificationPermission())
                }
                "getPendingSms" -> {
                    val prefs = getSharedPreferences("pending_sms", Context.MODE_PRIVATE)
                    val s = prefs.getString("sender", null)
                    val b = prefs.getString("body", null)
                    val ts = prefs.getLong("timestamp", 0L)
                    val uc = prefs.getBoolean("user_choice", false)

                    Log.d(tag, "[SMS_PARSED] getPendingSms sender=$s userChoice=$uc")

                    if (s != null && b != null) {
                        result.success(
                            mapOf(
                                "sender" to s,
                                "body" to b,
                                "timestamp" to ts,
                                "user_choice" to uc,
                            ),
                        )
                    } else {
                        result.success(null)
                    }
                }
                "clearPendingSms" -> {
                    getSharedPreferences("pending_sms", Context.MODE_PRIVATE).edit().clear().apply()
                    Log.d(tag, "[OFFLINE_QUEUE] clearPendingSms")
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        Log.i(tag, "[SMS_CHANNEL] FlutterEngine configured MethodChannel=$channelName")
    }

    private fun checkSmsPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED &&
                ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun checkNotificationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun requestSmsPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        if (!checkSmsPermission()) {
            Log.i(tag, "[SMS_RECEIVED] requesting SMS runtime permissions")
            ActivityCompat.requestPermissions(
                this,
                arrayOf(
                    Manifest.permission.RECEIVE_SMS,
                    Manifest.permission.READ_SMS,
                ),
                smsPermissionCode,
            )
        } else {
            Log.d(tag, "[SMS_RECEIVED] SMS permissions already granted")
        }
    }

    private fun requestPostNotificationsIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) {
                Log.i(tag, "[SMS_RECEIVED] requesting POST_NOTIFICATIONS")
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    notificationPermissionCode,
                )
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            smsPermissionCode -> {
                val ok = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
                Log.i(tag, "[SMS_RECEIVED] SMS permission result granted=$ok")
            }
            notificationPermissionCode -> {
                val ok = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
                Log.i(tag, "[SMS_RECEIVED] POST_NOTIFICATIONS result granted=$ok")
            }
        }
    }

    override fun onDestroy() {
        Log.i(tag, "[SMS_CHANNEL] MainActivity onDestroy — detach MethodChannel")
        SmsReceiver.setMethodChannel(null)
        SmsActionReceiver.setMethodChannel(null)
        smsMethodChannel = null
        super.onDestroy()
    }
}
