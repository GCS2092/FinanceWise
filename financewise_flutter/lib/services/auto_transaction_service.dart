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

  Future<Map<String, dynamic>?> parseSms(String smsBody, String sender) async {
    // Détection du fournisseur
    String provider = 'unknown';
    if (sender.contains('Wave') || sender.toLowerCase().contains('wave')) {
      provider = 'wave';
    } else if (sender.contains('Orange') || sender.toLowerCase().contains('orange')) {
      provider = 'orange_money';
    }

    if (provider == 'unknown') return null;

    // Parsing du montant
    final amountRegex = RegExp(r'(\d+[.,]?\d*)\s*(?:FCFA|XOF|F|CFA)');
    final amountMatch = amountRegex.firstMatch(smsBody);
    if (amountMatch == null) return null;

    final amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', '.')) ?? 0;
    if (amount == 0) return null;

    // Détection du type (revenu/dépense)
    final type = smsBody.toLowerCase().contains('reçu') || 
                 smsBody.toLowerCase().contains('dépot') ||
                 smsBody.toLowerCase().contains('crédit') ? 'income' : 'expense';

    // Détection de la catégorie automatique
    final category = _detectCategory(smsBody);

    return {
      'provider': provider,
      'amount': amount,
      'type': type,
      'category': category,
      'description': _generateDescription(smsBody, provider),
      'raw_sms': smsBody,
      'sender': sender,
    };
  }

  String _detectCategory(String smsBody) {
    final lowerBody = smsBody.toLowerCase();
    
    // Mots-clés par catégorie
    final categoryKeywords = {
      'nourriture': ['restaurant', 'nourriture', 'food', 'manger', 'café', 'bar'],
      'transport': ['taxi', 'bus', 'transport', 'car', 'essence', 'station'],
      'shopping': ['achat', 'shopping', 'magasin', 'boutique', 'supermarché'],
      'facture': ['facture', 'eau', 'électricité', 'internet', 'sénélec', 'sde'],
      'santé': ['pharmacie', 'hôpital', 'santé', 'médicament', 'clinique'],
      'éducation': ['école', 'cours', 'formation', 'livre', 'éducation'],
      'communication': ['airtel', 'orange', 'expresso', 'credit', 'appel', 'internet'],
    };

    for (final entry in categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (lowerBody.contains(keyword)) {
          return entry.key;
        }
      }
    }

    // Catégorie par défaut selon le type
    return 'divers';
  }

  String _generateDescription(String smsBody, String provider) {
    // Extraire une description pertinente du SMS
    final words = smsBody.split(' ');
    final filtered = words.where((w) => w.length > 3).toList();
    if (filtered.length >= 2) {
      return '${provider} - ${filtered.sublist(0, 3).join(' ')}';
    }
    return 'Transaction $provider';
  }

  Future<void> addTransaction(Map<String, dynamic> parsedData, BuildContext? context) async {
    try {
      // Récupérer le wallet par défaut
      final wallets = await _api.get('/wallets');
      final walletList = wallets is Map ? (wallets['data'] ?? []) : wallets;
      if (walletList == null || walletList.isEmpty) {
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucun wallet disponible')),
          );
        }
        return;
      }

      final defaultWallet = walletList[0];
      final walletId = defaultWallet['id'];

      // Récupérer ou créer la catégorie
      final categories = await _api.get('/categories');
      final categoryList = categories is Map ? (categories['data'] ?? []) : categories;
      
      String? categoryId;
      if (categoryList != null && categoryList.isNotEmpty) {
        final existingCategory = categoryList.firstWhere(
          (c) => c['name'] == parsedData['category'],
          orElse: () => null,
        );
        if (existingCategory != null) {
          categoryId = existingCategory['id'];
        }
      }

      // Créer la transaction
      final transactionData = {
        'wallet_id': walletId,
        'category_id': categoryId,
        'type': parsedData['type'],
        'amount': parsedData['amount'],
        'description': parsedData['description'],
        'transaction_date': DateTime.now().toIso8601String().split('T').first,
        'source': 'auto_${parsedData['provider']}',
      };

      await _api.post('/transactions', transactionData);

      // Notification de succès
      await NotificationService().showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: 'Transaction ajoutée automatiquement',
        body: '${parsedData['type'] == 'income' ? 'Revenu' : 'Dépense'} de ${parsedData['amount']} XOF',
      );

      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transaction ajoutée: ${parsedData['amount']} XOF')),
        );
      }
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  void showConfirmDialog(BuildContext context, Map<String, dynamic> parsedData) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle transaction détectée'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Montant: ${parsedData['amount']} XOF'),
            Text('Type: ${parsedData['type'] == 'income' ? 'Revenu' : 'Dépense'}'),
            Text('Catégorie: ${parsedData['category']}'),
            Text('Description: ${parsedData['description']}'),
            const SizedBox(height: 16),
            const Text('Souhaitez-vous ajouter cette transaction ?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ignorer'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              addTransaction(parsedData, context);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }
}
