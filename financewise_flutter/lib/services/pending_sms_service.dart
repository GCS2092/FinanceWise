import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';
import 'auto_transaction_service.dart';
import 'sms_parser_service.dart';
import '../theme.dart';

class PendingSmsService {
  static const _channel = MethodChannel('com.example.financewise_flutter/sms');

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
      print('PendingSmsService: Résultat getPendingSms=$result');
      
      if (result != null && result is Map) {
        final sender = result['sender'] as String?;
        final body = result['body'] as String?;
        final timestamp = result['timestamp'] as int?;
        final userChoice = result['user_choice'] as bool?;
        
        print('PendingSmsService: sender=$sender, body=$body, userChoice=$userChoice');
        
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
      print('PendingSmsService: Pending SMS cleared via MethodChannel');
    } catch (e) {
      print('PendingSmsService: Erreur clearPendingSms=$e');
    }
  }
  
  static Future<void> showPendingSmsDialog(BuildContext context, {VoidCallback? onTransactionAdded}) async {
    final pendingSms = await getPendingSms();

    if (pendingSms != null) {
      final sender = pendingSms['sender'] as String;
      final body = pendingSms['body'] as String;
      final userChoice = pendingSms['user_choice'] as bool;

      print('PendingSmsService: Traitement SMS - userChoice=$userChoice');

      if (!userChoice) {
        print('PendingSmsService: Utilisateur n\'a pas choisi "Ajouter", effacement');
        await clearPendingSms();
        return;
      }

      // Charger les wallets pour la sélection automatique
      print('PendingSmsService: Début chargement wallets');
      await _loadWallets();
      print('PendingSmsService: Wallets chargés, défaut=$_defaultWalletId');

      // Parser le SMS localement
      final parserService = SmsParserService();
      final transaction = await parserService.parseSmsWithCategories(body, sender);
      print('PendingSmsService: Transaction parsée=$transaction');
      print('PendingSmsService: transaction != null: ${transaction != null}');

      if (transaction != null) {
        // Sélectionner le wallet selon les mots-clés et le sender
        final walletId = _selectWalletFromKeywords(body, sender);
        print('PendingSmsService: Wallet ID sélectionné=$walletId');

        try {
          final api = ApiService();
          final transactionData = transaction.toJson();
          print('PendingSmsService: Données transaction avant wallet_id=$transactionData');

          if (walletId != null) {
            transactionData['wallet_id'] = walletId;
            print('PendingSmsService: Wallet ID ajouté=$walletId');
          } else {
            print('PendingSmsService: ATTENTION: wallet_id est null!');
          }

          print('PendingSmsService: Données finales=$transactionData');
          final result = await api.post('/transactions', transactionData);
          print('PendingSmsService: Résultat API=$result');

          if (result is Map<String, dynamic>) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Transaction ajoutée avec succès'),
                  backgroundColor: AppTheme.success,
                ),
              );
            }
            // Rafraîchir le dashboard
            onTransactionAdded?.call();
          } else {
            print('PendingSmsService: Erreur - résultat API n\'est pas une Map');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Erreur lors de l\'ajout de la transaction'),
                  backgroundColor: AppTheme.error,
                ),
              );
            }
          }
        } catch (e) {
          print('PendingSmsService: Exception=$e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur: $e'),
                backgroundColor: AppTheme.error,
              ),
            );
          }
        }
      }

      // Effacer les données après traitement
      await clearPendingSms();
      print('PendingSmsService: Données effacées');
    }
  }
}
