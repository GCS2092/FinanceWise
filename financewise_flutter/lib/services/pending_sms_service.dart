import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../widgets/sms_confirmation_dialog.dart';
import 'api_service.dart';
import 'auto_transaction_service.dart';
import 'logger_service.dart';
import 'sms_parser_service.dart';

class PendingSmsService {
  static const _channel = MethodChannel('com.example.financewise_flutter/sms');
  static final LoggerService _log = LoggerService();

  static const Duration _maxPendingAge = Duration(minutes: 20);

  // Cache des wallets
  static List<dynamic> _wallets = [];
  static String? _defaultWalletId;

  // Correspondance mots-clés → types de wallets
  static const Map<String, String> _keywordToWalletType = {
    // Transport
    'yango': 'transport',
    'taxi': 'transport',
    'bus': 'transport',
    'car': 'transport',
    'véhicule': 'transport',
    'transport': 'transport',
    'essence': 'transport',
    'carburant': 'transport',
    'gazoil': 'transport',

    // Alimentation
    'boutiquier': 'alimentation',
    'restaurant': 'alimentation',
    'café': 'alimentation',
    'fast food': 'alimentation',
    'snack': 'alimentation',
    'manger': 'alimentation',
    'repas': 'alimentation',
    'food': 'alimentation',
    'aliment': 'alimentation',
    'supermarché': 'alimentation',
    'market': 'alimentation',

    // Téléphone
    'orange': 'téléphone',
    'wave': 'téléphone',
    'free': 'téléphone',
    'expresso': 'téléphone',
    'internet': 'téléphone',
    'data': 'téléphone',
    'appel': 'téléphone',
    'sms': 'téléphone',
    'credit': 'téléphone',

    // Argent/Cash
    'cash': 'espèces',
    'espèces': 'espèces',
    'argent': 'espèces',
    'retrait': 'espèces',

    // Banque
    'banque': 'banque',
    'cb': 'banque',
    'carte': 'banque',
    'virement': 'banque',
  };

  // Charger les wallets depuis l'API
  static Future<void> _loadWallets() async {
    try {
      print('PendingSmsService: Appel API /wallets');
      final api = ApiService();
      final result = await api.get('/wallets');
      print('PendingSmsService: Résultat API wallets=$result');
      
      if (result is Map && result.containsKey('data')) {
        _wallets = result['data'] as List;
      } else if (result is List) {
        _wallets = result;
      }

      // Définir le wallet par défaut
      if (_wallets.isNotEmpty) {
        _defaultWalletId = _wallets.first['id']?.toString();
      }
    } catch (e) {
      print('Erreur lors du chargement des wallets: $e');
    }
  }

  // Sélectionner le wallet selon les mots-clés du SMS et le sender
  static String? _selectWalletFromKeywords(String smsBody, String sender) {
    final lowerBody = smsBody.toLowerCase();
    final lowerSender = sender.toLowerCase();

    // Si aucun wallet n'est disponible, retourner null pour que l'API crée un wallet Divers
    if (_wallets.isEmpty) {
      print('PendingSmsService: Aucun wallet disponible, wallet_id sera null');
      return null;
    }

    // Priorité 1: Chercher un wallet correspondant au sender (Wave, Orange Money, etc.)
    for (final wallet in _wallets) {
      final walletNameLower = (wallet['name'] ?? '').toString().toLowerCase();
      final walletTypeLower = (wallet['type'] ?? '').toString().toLowerCase();
      
      // Si le sender contient "wave" et le wallet contient "wave"
      if (lowerSender.contains('wave') && walletNameLower.contains('wave')) {
        print('PendingSmsService: Wallet Wave sélectionné: ${wallet['name']}');
        return wallet['id']?.toString();
      }
      // Si le sender contient "orange" et le wallet contient "orange"
      if (lowerSender.contains('orange') && walletNameLower.contains('orange')) {
        print('PendingSmsService: Wallet Orange Money sélectionné: ${wallet['name']}');
        return wallet['id']?.toString();
      }
      // Si le sender contient "free" et le wallet contient "free"
      if (lowerSender.contains('free') && walletNameLower.contains('free')) {
        print('PendingSmsService: Wallet Free Money sélectionné: ${wallet['name']}');
        return wallet['id']?.toString();
      }
      // Si le sender contient "wari" et le wallet contient "wari"
      if (lowerSender.contains('wari') && walletNameLower.contains('wari')) {
        print('PendingSmsService: Wallet Wari sélectionné: ${wallet['name']}');
        return wallet['id']?.toString();
      }
    }

    // Priorité 2: Chercher le type de wallet correspondant via mots-clés
    String? walletType;
    for (final entry in _keywordToWalletType.entries) {
      if (lowerBody.contains(entry.key)) {
        walletType = entry.value;
        break;
      }
    }

    if (walletType == null) {
      // Aucun mot-clé trouvé, utiliser le wallet par défaut
      print('PendingSmsService: Aucun mot-clé trouvé, wallet par défaut: $_defaultWalletId');
      return _defaultWalletId;
    }

    // Chercher un wallet correspondant au type
    for (final wallet in _wallets) {
      final walletTypeLower = (wallet['type'] ?? '').toString().toLowerCase();
      final walletNameLower = (wallet['name'] ?? '').toString().toLowerCase();

      if (walletTypeLower.contains(walletType) || walletNameLower.contains(walletType)) {
        print('PendingSmsService: Wallet sélectionné par type: ${wallet['name']}');
        return wallet['id']?.toString();
      }
    }

    // Aucun wallet correspondant, utiliser le défaut
    print('PendingSmsService: Aucun wallet correspondant, wallet par défaut: $_defaultWalletId');
    return _defaultWalletId;
  }
  
  static Future<Map<String, dynamic>?> getPendingSms() async {
    try {
      final result = await _channel.invokeMethod('getPendingSms');
      _log.debug('[FLUTTER_SMS_RECEIVED] getPendingSms result=$result');
      
      if (result != null && result is Map) {
        final sender = result['sender'] as String?;
        final body = result['body'] as String?;
        final timestamp = result['timestamp'] as int?;
        final userChoice = result['user_choice'] as bool?;
        
        _log.debug('[FLUTTER_SMS_RECEIVED] pending fields sender=$sender userChoice=$userChoice');
        
        if (sender != null && body != null) {
          return {
            'sender': sender,
            'body': body,
            'timestamp': timestamp,
            'user_choice': userChoice,
          };
        }
      }
    } catch (e) {
      print('PendingSmsService: Erreur getPendingSms=$e');
    }
    
    return null;
  }
  
  static Future<void> clearPendingSms() async {
    try {
      await _channel.invokeMethod('clearPendingSms');
      _log.debug('[OFFLINE_QUEUE] clearPendingSms OK');
    } catch (e) {
      print('PendingSmsService: Erreur clearPendingSms=$e');
    }
  }
  
  static Future<void> showPendingSmsDialog(BuildContext context, {VoidCallback? onTransactionAdded}) async {
    final pendingSms = await getPendingSms();
    if (pendingSms == null) return;

    final sender = pendingSms['sender'] as String;
    final body = pendingSms['body'] as String;
    final userChoice = pendingSms['user_choice'] as bool;
    final ts = pendingSms['timestamp'] as int?;

    if (ts != null) {
      final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
      if (age > _maxPendingAge) {
        _log.debug('[FLUTTER_SMS_RECEIVED] pending expiré (${age.inMinutes} min) — effacement');
        await clearPendingSms();
        return;
      }
    }

    _log.debug('[FLUTTER_SMS_RECEIVED] showPendingSmsDialog userChoice=$userChoice');

    final auto = AutoTransactionService();
    await auto.loadSettings();

    if (userChoice) {
      await _loadWallets();
      final parserService = SmsParserService();
      final transaction = await parserService.parseSmsWithCategories(body, sender);
      if (transaction == null) {
        await clearPendingSms();
        return;
      }
      final walletId = _selectWalletFromKeywords(body, sender);
      try {
        final api = ApiService();
        final transactionData = transaction.toJson();
        if (walletId != null) {
          transactionData['wallet_id'] = walletId;
        }
        _log.debug('[OFFLINE_QUEUE] POST /transactions (userChoice notification Ajouter)');
        final result = await api.post('/transactions', transactionData);
        if (result is Map<String, dynamic>) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Transaction ajoutée avec succès'), backgroundColor: AppTheme.success),
            );
          }
          onTransactionAdded?.call();
        }
      } catch (e) {
        _log.error('[SYNC] PendingSmsService POST erreur: $e', e);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.error),
          );
        }
      }
      await clearPendingSms();
      return;
    }

    // userChoice == false : SMS stocké par SmsReceiver / notification — proposer le dialogue
    if (!auto.hasAmount(body)) {
      _log.debug('[TRANSACTION_DETECTED] pending sans montant détectable — abandon');
      await clearPendingSms();
      return;
    }
    if (auto.detectProvider(sender, body) == null) {
      _log.debug('[TRANSACTION_DETECTED] pending sans fournisseur reconnu — abandon');
      await clearPendingSms();
      return;
    }

    await _loadWallets();
    final parserService = SmsParserService();
    final transaction = await parserService.parseSmsWithCategories(body, sender);
    if (transaction != null && context.mounted) {
      _log.debug('[TRANSACTION_DETECTED] affichage dialogue confirmation (cold start / prefs)');
      final confirmed = await showSmsConfirmationDialog(context, transaction);
      if (confirmed == true) {
        onTransactionAdded?.call();
      }
    }

    await clearPendingSms();
  }
}
