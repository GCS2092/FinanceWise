import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'sms_parser_service.dart';
import '../widgets/sms_confirmation_dialog.dart';

class SmsListenerService {
  static const _channel = MethodChannel('com.example.financewise_flutter/sms');
  static SmsListenerService? _instance;
  
  final BuildContext context;
  final VoidCallback? onTransactionAdded;
  
  SmsListenerService._({
    required this.context,
    this.onTransactionAdded,
  });
  
  static SmsListenerService getInstance({
    required BuildContext context,
    VoidCallback? onTransactionAdded,
  }) {
    _instance ??= SmsListenerService._(
      context: context,
      onTransactionAdded: onTransactionAdded,
    );
    return _instance!;
  }
  
  void startListening() {
    _channel.setMethodCallHandler(_handleSmsReceived);
  }
  
  void stopListening() {
    _channel.setMethodCallHandler(null);
  }
  
  Future<void> _handleSmsReceived(MethodCall call) async {
    if (call.method == 'onSmsReceived') {
      final smsData = call.arguments as Map<dynamic, dynamic>;
      final sender = smsData['sender'] as String;
      final body = smsData['body'] as String;
      
      // Parser le SMS
      final parserService = SmsParserService();
      final transaction = await parserService.parseSmsWithCategories(body, sender);
      
      if (transaction != null) {
        // Afficher le popup de confirmation
        if (context.mounted) {
          final confirmed = await showSmsConfirmationDialog(context, transaction);
          
          if (confirmed == true && onTransactionAdded != null) {
            onTransactionAdded?.call();
          }
        }
      }
    }
  }
  
  static Future<bool> requestSmsPermission() async {
    try {
      final result = await _channel.invokeMethod('requestSmsPermission');
      return result as bool? ?? false;
    } catch (e) {
      return false;
    }
  }
}
