import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auto_transaction_service.dart';
import 'sms_parser_service.dart';
import '../widgets/sms_confirmation_dialog.dart';

class PendingSmsService {
  static const _prefsKey = 'pending_sms';
  
  static Future<Map<String, dynamic>?> getPendingSms() async {
    final prefs = await SharedPreferences.getInstance();
    final sender = prefs.getString('sender');
    final body = prefs.getString('body');
    final timestamp = prefs.getInt('timestamp') ?? 0;
    
    if (sender != null && body != null) {
      return {
        'sender': sender,
        'body': body,
        'timestamp': timestamp,
      };
    }
    
    return null;
  }
  
  static Future<void> clearPendingSms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sender');
    await prefs.remove('body');
    await prefs.remove('timestamp');
  }
  
  static Future<void> showPendingSmsDialog(BuildContext context) async {
    final pendingSms = await getPendingSms();
    
    if (pendingSms != null) {
      final sender = pendingSms['sender'] as String;
      final body = pendingSms['body'] as String;
      
      // Parser le SMS localement
      final parserService = SmsParserService();
      final transaction = await parserService.parseSmsWithCategories(body, sender);
      
      if (transaction != null) {
        // Afficher le dialog de confirmation
        final confirmed = await showSmsConfirmationDialog(context, transaction);
        
        if (confirmed == true) {
          // Transaction confirmée par l'utilisateur
          // Effacer les données après confirmation
          await clearPendingSms();
        }
      } else {
        // Si le parsing échoue, essayer d'envoyer au backend
        final autoService = AutoTransactionService();
        await autoService.handleAutoSms(body, sender, context);
        await clearPendingSms();
      }
    }
  }
}
