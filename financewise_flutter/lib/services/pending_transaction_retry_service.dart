import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'notification_service.dart';

class PendingTransactionRetryService {
  static const _prefsKey = 'pending_transactions';
  static final PendingTransactionRetryService _instance = PendingTransactionRetryService._internal();
  factory PendingTransactionRetryService() => _instance;
  PendingTransactionRetryService._internal();

  final ApiService _api = ApiService();
  bool _isRetrying = false;

  /// Récupère les transactions en attente
  Future<List<Map<String, dynamic>>> _getPendingTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingList = prefs.getStringList(_prefsKey) ?? [];
    
    return pendingList.map((item) {
      try {
        return Map<String, dynamic>.from(
          (item as String).startsWith('{')
            ? (item as String).split(',').asMap().entries.fold<Map<String, dynamic>>(
                {}, (map, entry) {
                  final key = entry.value.trim().split(':').first.replaceAll(RegExp(r"""[{}'"()]"""), '').trim();
                  final value = entry.value.trim().split(':').skip(1).join(':').replaceAll(RegExp(r"""[{}'"()]"""), '').trim();
                  if (key.isNotEmpty && value.isNotEmpty) {
                    map[key] = value;
                  }
                  return map;
                })
            : <String, dynamic>{}
        );
      } catch (e) {
        return <String, dynamic>{};
      }
    }).where((t) => t.isNotEmpty).toList();
  }

  /// Sauvegarde les transactions en attente
  Future<void> _savePendingTransactions(List<Map<String, dynamic>> transactions) async {
    final prefs = await SharedPreferences.getInstance();
    final stringList = transactions.map((t) => t.toString()).toList();
    await prefs.setStringList(_prefsKey, stringList);
  }

  /// Tente de resynchroniser toutes les transactions en attente
  Future<void> retryPendingTransactions() async {
    if (_isRetrying) return;
    
    _isRetrying = true;
    
    try {
      await _api.init();
      
      if (!_api.isAuthenticated) {
        return;
      }
      
      final pendingTransactions = await _getPendingTransactions();
      
      if (pendingTransactions.isEmpty) {
        return;
      }
      
      final successfullySynced = <Map<String, dynamic>>[];
      final failedTransactions = <Map<String, dynamic>>[];
      
      for (final transaction in pendingTransactions) {
        try {
          // Convertir les types de données
          final data = {
            'amount': double.tryParse(transaction['amount']?.toString() ?? '0') ?? 0,
            'type': transaction['type']?.toString() ?? 'expense',
            'category_id': int.tryParse(transaction['category_id']?.toString() ?? '0'),
            'wallet_id': int.tryParse(transaction['wallet_id']?.toString() ?? '0'),
            'description': transaction['description']?.toString() ?? '',
            'transaction_date': transaction['transaction_date']?.toString() ?? DateTime.now().toIso8601String(),
          };
          
          // Envoyer à l'API
          await _api.post('/transactions', data);
          successfullySynced.add(transaction);
        } catch (e) {
          failedTransactions.add(transaction);
        }
      }
      
      // Sauvegarder seulement les transactions échouées
      await _savePendingTransactions(failedTransactions);
      
      // Notifier l'utilisateur si des transactions ont été synchronisées
      if (successfullySynced.isNotEmpty) {
        await NotificationService().showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'Synchronisation terminée',
          body: '${successfullySynced.length} transaction(s) synchronisée(s)',
        );
      }
    } catch (e) {
      // Erreur silencieuse, on réessaiera au prochain démarrage
    } finally {
      _isRetrying = false;
    }
  }

  /// Vide toutes les transactions en attente
  Future<void> clearPendingTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  /// Compte le nombre de transactions en attente
  Future<int> getPendingCount() async {
    final pendingTransactions = await _getPendingTransactions();
    return pendingTransactions.length;
  }
}
