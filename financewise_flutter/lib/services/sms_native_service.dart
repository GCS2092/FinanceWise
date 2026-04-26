import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'auto_transaction_service.dart';

class SmsNativeService {
  static const MethodChannel _channel = MethodChannel('com.example.financewise_flutter/sms');
  static final SmsNativeService _instance = SmsNativeService._internal();
  factory SmsNativeService() => _instance;
  SmsNativeService._internal();

  final AutoTransactionService _autoService = AutoTransactionService();
  bool _isListening = false;

  Future<void> initialize(BuildContext context) async {
    await _autoService.loadSettings();
    
    if (!_autoService.isEnabled) {
      return;
    }

    // Demander les permissions SMS
    final status = await Permission.sms.request();
    if (!status.isGranted) {
      return;
    }

    // Écouter les SMS depuis Android natif
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSmsReceived') {
        final smsData = call.arguments as Map<String, dynamic>;
        _handleSms(smsData, context);
      }
    });

    _isListening = true;
  }

  void _handleSms(Map<String, dynamic> smsData, BuildContext context) async {
    if (!_autoService.isEnabled) return;

    final sender = smsData['sender'] ?? '';
    final body = smsData['body'] ?? '';

    // Parser le SMS
    final parsedData = await _autoService.parseSms(body, sender);
    if (parsedData == null) return;

    // Si auto-confirmation est activé, ajouter directement
    if (_autoService.autoConfirm) {
      await _autoService.addTransaction(parsedData, context);
    } else {
      // Sinon, afficher la dialog de confirmation
      if (context.mounted) {
        _autoService.showConfirmDialog(context, parsedData);
      }
    }
  }

  void stopListening() {
    _channel.setMethodCallHandler(null);
    _isListening = false;
  }

  bool get isListening => _isListening;
}
