import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auto_transaction_service.dart';
import 'sms_parser_service.dart';
import '../widgets/sms_confirmation_dialog.dart';
import '../theme.dart';

class SmsListenerService {
  static const _channel = MethodChannel('com.example.financewise_flutter/sms');
  static SmsListenerService? _instance;

  final BuildContext context;
  final VoidCallback? onTransactionAdded;
  final AutoTransactionService _autoService = AutoTransactionService();
  final SmsParserService _parserService = SmsParserService();

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

      // Parser le SMS localement
      final transaction = await _parserService.parseSmsWithCategories(body, sender);

      if (transaction != null && context.mounted) {
        // Afficher le dialog de confirmation
        final confirmed = await showSmsConfirmationDialog(context, transaction);

        if (confirmed == true) {
          // Transaction confirmée par l'utilisateur
          // Rafraîchir le dashboard
          onTransactionAdded?.call();
        }
      }
    }
  }

  static Future<bool> requestSmsPermission() async {
    try {
      await _channel.invokeMethod('requestSmsPermission');
      return await checkSmsPermission();
    } catch (e) {
      return false;
    }
  }

  static Future<bool> checkSmsPermission() async {
    try {
      final result = await _channel.invokeMethod('checkSmsPermission');
      return result as bool? ?? false;
    } catch (e) {
      return false;
    }
  }
}
