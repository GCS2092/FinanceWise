package com.example.financewise_flutter

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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        // Connecter le MethodChannel au SmsReceiver
        SmsReceiver.setMethodChannel(methodChannel)
        
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
