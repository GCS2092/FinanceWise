import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auto_transaction_service.dart';

class SmsListenerService {
  static const _channel = MethodChannel('com.example.financewise_flutter/sms');
  static SmsListenerService? _instance;
  
  final BuildContext context;
  final VoidCallback? onTransactionAdded;
  final AutoTransactionService _autoService = AutoTransactionService();
  
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
      
      // Vérifier si c'est un SMS financier (Wave / Orange Money avec montant)
      final provider = _autoService.detectProvider(sender);
      if (provider == null || !_autoService.hasAmount(body)) return;

      // Envoyer au backend pour parsing async
      final result = await _autoService.sendToBackend(body, sender);

      if (result != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS financier détecté et envoyé pour traitement'),
            duration: Duration(seconds: 3),
          ),
        );
        // Rafraîchir le dashboard après un délai (le job aura eu le temps de traiter)
        Future.delayed(const Duration(seconds: 4), () {
          onTransactionAdded?.call();
        });
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
