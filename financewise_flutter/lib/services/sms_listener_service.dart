import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';
import 'auto_transaction_service.dart';
import 'sms_parser_service.dart';
import '../widgets/sms_confirmation_dialog.dart';
import '../theme.dart';

class SmsListenerService {
  static const _channel = MethodChannel('com.example.financewise_flutter/sms');
  static SmsListenerService? _instance;
  final BuildContext _context;
  final VoidCallback? _onTransactionAdded;
  final SmsParserService _parserService = SmsParserService();
  final AutoTransactionService _autoService = AutoTransactionService();
  final ApiService _api = ApiService();

  // Pour éviter le double traitement
  static String? _lastProcessedSms;
  static DateTime? _lastProcessedTime;

  SmsListenerService._({
    required BuildContext context,
    VoidCallback? onTransactionAdded,
  })  : _context = context,
        _onTransactionAdded = onTransactionAdded {
    _loadWallets();
  }

  // Cache des wallets
  List<dynamic> _wallets = [];
  String? _defaultWalletId;

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
  Future<void> _loadWallets() async {
    try {
      final result = await _api.get('/wallets');
      if (result is Map && result.containsKey('data')) {
        _wallets = result['data'] as List;
      } else if (result is List) {
        _wallets = result;
      }

      // Définir le wallet par défaut (le premier wallet ou celui avec le solde le plus élevé)
      if (_wallets.isNotEmpty) {
        _defaultWalletId = _wallets.first['id']?.toString();
      }
    } catch (e) {
      print('Erreur lors du chargement des wallets: $e');
    }
  }

  // Sélectionner le wallet selon les mots-clés du SMS
  String? _selectWalletFromKeywords(String smsBody) {
    final lowerBody = smsBody.toLowerCase();

    print('SMS Body: $smsBody');
    print('Wallets disponibles: $_wallets');
    print('Wallet par défaut: $_defaultWalletId');

    // Chercher le type de wallet correspondant
    String? walletType;
    for (final entry in _keywordToWalletType.entries) {
      if (lowerBody.contains(entry.key)) {
        walletType = entry.value;
        print('Mot-clé trouvé: ${entry.key} -> Type wallet: $walletType');
        break;
      }
    }

    if (walletType == null) {
      // Aucun mot-clé trouvé, utiliser le wallet par défaut
      print('Aucun mot-clé trouvé, utilisation wallet par défaut: $_defaultWalletId');
      return _defaultWalletId;
    }

    // Chercher un wallet correspondant au type
    for (final wallet in _wallets) {
      final walletTypeLower = (wallet['type'] ?? '').toString().toLowerCase();
      final walletNameLower = (wallet['name'] ?? '').toString().toLowerCase();

      print('Vérification wallet: ${wallet['name']} (type: ${wallet['type']}) contre $walletType');

      if (walletTypeLower.contains(walletType) || walletNameLower.contains(walletType)) {
        print('Wallet correspondant trouvé: ${wallet['id']}');
        return wallet['id']?.toString();
      }
    }

    // Aucun wallet correspondant, utiliser le défaut
    print('Aucun wallet correspondant, utilisation wallet par défaut: $_defaultWalletId');
    return _defaultWalletId;
  }

  static SmsListenerService getInstance({
    required BuildContext context,
    VoidCallback? onTransactionAdded,
  }) {
    // Toujours recréer l'instance pour s'assurer que le context est à jour
    _instance = SmsListenerService._(
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

      if (transaction != null && _context.mounted) {
        final confirmed = await showSmsConfirmationDialog(_context, transaction);

        if (confirmed == true) {
          _onTransactionAdded?.call();
        }
      }
    } else if (call.method == 'onSmsActionAdd') {
      // L'utilisateur a cliqué sur "Ajouter" depuis la notification
      final smsData = call.arguments as Map<dynamic, dynamic>;
      final sender = smsData['sender'] as String;
      final body = smsData['body'] as String;

      print('=== onSmsActionAdd ===');
      print('Sender: $sender');
      print('Body: $body');

      // Vérifier si ce SMS a déjà été traité récemment (pour éviter le double traitement)
      final smsKey = '$sender|$body';
      final now = DateTime.now();
      if (_lastProcessedSms == smsKey && 
          _lastProcessedTime != null && 
          now.difference(_lastProcessedTime!).inSeconds < 5) {
        print('SMS déjà traité récemment, ignoré');
        return;
      }

      // Marquer ce SMS comme traité
      _lastProcessedSms = smsKey;
      _lastProcessedTime = now;

      // Vérifier si c'est un SMS financier (Wave / Orange Money avec montant)
      final provider = _autoService.detectProvider(sender);
      print('Provider détecté: $provider');
      
      if (provider == null || !_autoService.hasAmount(body)) {
        print('SMS non valide ou sans montant');
        return;
      }

      // Parser le SMS localement
      final transaction = await _parserService.parseSmsWithCategories(body, sender);
      print('Transaction parsée: $transaction');

      if (transaction != null) {
        // Sélectionner le wallet selon les mots-clés
        final walletId = _selectWalletFromKeywords(body);
        print('Wallet ID sélectionné: $walletId');

        // Créer directement la transaction via l'API
        try {
          final transactionData = transaction.toJson();
          print('Données transaction avant ajout wallet_id=$transactionData');
          
          if (walletId != null) {
            transactionData['wallet_id'] = walletId;
            print('Wallet ID ajouté: $walletId');
          } else {
            print('ATTENTION: wallet_id est null!');
          }

          print('Données transaction finales=$transactionData');
          final result = await _api.post('/transactions', transactionData);
          print('Résultat API=$result');

          if (result is Map<String, dynamic>) {
            // Transaction créée avec succès
            if (_context.mounted) {
              ScaffoldMessenger.of(_context).showSnackBar(
                const SnackBar(
                  content: Text('Transaction ajoutée avec succès'),
                  backgroundColor: AppTheme.success,
                ),
              );
            }
            // Rafraîchir le dashboard
            _onTransactionAdded?.call();
            // Effacer le SMS en attente
            await _channel.invokeMethod('clearPendingSms');
          } else {
            // Erreur lors de la création
            print('Erreur: résultat API n\'est pas une Map');
            if (_context.mounted) {
              ScaffoldMessenger.of(_context).showSnackBar(
                const SnackBar(
                  content: Text('Erreur lors de l\'ajout de la transaction'),
                  backgroundColor: AppTheme.error,
                ),
              );
            }
          }
        } catch (e) {
          print('Erreur lors de la création de la transaction: $e');
          if (_context.mounted) {
            ScaffoldMessenger.of(_context).showSnackBar(
              SnackBar(
                content: Text('Erreur: $e'),
                backgroundColor: AppTheme.error,
              ),
            );
          }
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
