import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class AutoTransactionService {
  static final AutoTransactionService _instance = AutoTransactionService._internal();
  factory AutoTransactionService() => _instance;
  AutoTransactionService._internal();

  final ApiService _api = ApiService();
  bool _isEnabled = false;
  bool _autoConfirm = false;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('auto_transaction_enabled') ?? false;
    _autoConfirm = prefs.getBool('auto_transaction_confirm') ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = enabled;
    await prefs.setBool('auto_transaction_enabled', enabled);
  }

  Future<void> setAutoConfirm(bool autoConfirm) async {
    final prefs = await SharedPreferences.getInstance();
    _autoConfirm = autoConfirm;
    await prefs.setBool('auto_transaction_confirm', autoConfirm);
  }

  bool get isEnabled => _isEnabled;
  bool get autoConfirm => _autoConfirm;

  /// Détecte le fournisseur depuis l’expéditeur **et** le corps (codes courts réels sur téléphone).
  String? detectProvider(String sender, [String body = '']) {
    final hay = '${sender.toLowerCase()} ${body.toLowerCase()}';
    if (hay.contains('wave')) return 'wave';
    if (hay.contains('orange') || hay.contains('orangemoney') || hay.contains('orange money')) {
      return 'orange_money';
    }
    if (hay.contains('yango')) return 'yango';
    if (hay.contains('taxi')) return 'taxi';
    if (hay.contains('bolt')) return 'bolt';
    if (hay.contains('uber')) return 'uber';
    if (hay.contains('free')) return 'free';
    if (hay.contains('expresso')) return 'expresso';
    if (hay.contains('wari')) return 'wari';
    if (hay.contains('jonah')) return 'jonah';
    return null;
  }

  /// Vérifie si le SMS contient un montant (filtre rapide avant d'envoyer au backend)
  bool hasAmount(String smsBody) {
    // Pattern pour montants avec devise (gère espaces, virgules et points)
    final amountRegexWithCurrency = RegExp(r'(\d{1,3}(?:[ ,.]\d{3})*(?:[.,]\d+)?)\s*(?:FCFA|XOF|F|CFA)');
    if (amountRegexWithCurrency.hasMatch(smsBody)) return true;
    
    // Pattern pour grands nombres sans séparateurs avec devise
    final amountRegexLarge = RegExp(r'(\d{4,})\s*(?:FCFA|XOF|F|CFA)');
    if (amountRegexLarge.hasMatch(smsBody)) return true;
    
    // Pattern pour montants sans devise (nombres entre 3 et 7 chiffres)
    final amountRegexWithoutCurrency = RegExp(r'\b(\d{3,7})\b');
    return amountRegexWithoutCurrency.hasMatch(smsBody);
  }

  /// Envoie le SMS au backend pour parsing async via la queue
  Future<Map<String, dynamic>?> sendToBackend(String smsBody, String sender) async {
    final provider = detectProvider(sender, smsBody);
    if (provider == null) return null;
    // API Laravel `/sms/parse` : uniquement wave | orange_money
    if (provider != 'wave' && provider != 'orange_money') return null;
    if (!hasAmount(smsBody)) return null;

    try {
      final response = await _api.post('/sms/parse', {
        'provider': provider,
        'raw_content': smsBody,
      });

      if (response is Map<String, dynamic> && response['sms'] != null) {
        return response;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Gestion automatique : envoie au backend + notifie l'utilisateur
  Future<void> handleAutoSms(String smsBody, String sender, BuildContext? context) async {
    if (!_isEnabled) return;

    final provider = detectProvider(sender, smsBody);
    if (provider == null) return;
    if (!hasAmount(smsBody)) return;

    try {
      final result = await sendToBackend(smsBody, sender);

      if (result != null) {
        // SMS accepté par le backend (202)
        await NotificationService().showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'SMS détecté',
          body: 'Transaction en cours de traitement depuis $sender',
        );

        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SMS envoyé au serveur pour traitement')),
          );
        }
      }
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'envoi SMS : $e')),
        );
      }
    }
  }

}
