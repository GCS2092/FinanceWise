package com.example.financewise_flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.financewise_flutter/sms"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        // Connecter le MethodChannel au SmsReceiver
        SmsReceiver.setMethodChannel(methodChannel)
        
        // Handler pour les appels depuis Flutter
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestSmsPermission" -> {
                    // Pourrait demander les permissions SMS ici si nécessaire
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
