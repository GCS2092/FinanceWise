import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'notification_service.dart';

class OfflineGoalService {
  static const _goalsKey = 'offline_goals';
  static const _goalHistoryKey = 'offline_goal_history';
  static final OfflineGoalService _instance = OfflineGoalService._internal();
  factory OfflineGoalService() => _instance;
  OfflineGoalService._internal();

  final ApiService _api = ApiService();
  bool _isSyncing = false;

  /// Récupère les objectifs stockés localement
  Future<List<Map<String, dynamic>>> _getOfflineGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final goalsList = prefs.getStringList(_goalsKey) ?? [];
    
    return goalsList.map((item) {
      try {
        return Map<String, dynamic>.from(jsonDecode(item));
      } catch (e) {
        return <String, dynamic>{};
      }
    }).where((g) => g.isNotEmpty).toList();
  }

  /// Sauvegarde les objectifs localement
  Future<void> _saveOfflineGoals(List<Map<String, dynamic>> goals) async {
    final prefs = await SharedPreferences.getInstance();
    final stringList = goals.map((g) => jsonEncode(g)).toList();
    await prefs.setStringList(_goalsKey, stringList);
  }

  /// Récupère l'historique des ajouts stocké localement
  Future<List<Map<String, dynamic>>> _getOfflineGoalHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyList = prefs.getStringList(_goalHistoryKey) ?? [];
    
    return historyList.map((item) {
      try {
        return Map<String, dynamic>.from(jsonDecode(item));
      } catch (e) {
        return <String, dynamic>{};
      }
    }).where((h) => h.isNotEmpty).toList();
  }

  /// Sauvegarde l'historique localement
  Future<void> _saveOfflineGoalHistory(List<Map<String, dynamic>> history) async {
    final prefs = await SharedPreferences.getInstance();
    final stringList = history.map((h) => jsonEncode(h)).toList();
    await prefs.setStringList(_goalHistoryKey, stringList);
  }

  /// Crée un objectif hors ligne
  Future<void> createGoalOffline(Map<String, dynamic> goalData) async {
    final offlineGoals = await _getOfflineGoals();
    final newGoal = {
      ...goalData,
      'id': DateTime.now().millisecondsSinceEpoch,
      'created_at': DateTime.now().toIso8601String(),
      '_offline': true,
      '_synced': false,
    };
    offlineGoals.add(newGoal);
    await _saveOfflineGoals(offlineGoals);
  }

  /// Ajoute un montant hors ligne
  Future<void> addAmountOffline(int goalId, double amount) async {
    final offlineGoals = await _getOfflineGoals();
    final goalIndex = offlineGoals.indexWhere((g) => g['id'] == goalId);
    
    if (goalIndex != -1) {
      final currentAmount = (offlineGoals[goalIndex]['current_amount'] as num?)?.toDouble() ?? 0;
      offlineGoals[goalIndex]['current_amount'] = currentAmount + amount;
      offlineGoals[goalIndex]['_modified'] = true;
      await _saveOfflineGoals(offlineGoals);
      
      // Enregistrer dans l'historique
      final offlineHistory = await _getOfflineGoalHistory();
      offlineHistory.add({
        'id': DateTime.now().millisecondsSinceEpoch,
        'financial_goal_id': goalId,
        'amount': amount,
        'balance_before': currentAmount,
        'balance_after': currentAmount + amount,
        'type': amount >= 0 ? 'add' : 'remove',
        'created_at': DateTime.now().toIso8601String(),
        '_offline': true,
        '_synced': false,
      });
      await _saveOfflineGoalHistory(offlineHistory);
    }
  }

  /// Synchronise les objectifs avec le serveur
  Future<void> syncGoals() async {
    if (_isSyncing) return;
    
    _isSyncing = true;
    
    try {
      await _api.init();
      
      if (!_api.isAuthenticated) {
        return;
      }
      
      final offlineGoals = await _getOfflineGoals();
      final offlineHistory = await _getOfflineGoalHistory();
      
      if (offlineGoals.isEmpty && offlineHistory.isEmpty) {
        return;
      }
      
      final syncedGoals = <Map<String, dynamic>>[];
      final syncedHistory = <Map<String, dynamic>>[];
      final failedGoals = <Map<String, dynamic>>[];
      final failedHistory = <Map<String, dynamic>>[];
      
      // Synchroniser les objectifs
      for (final goal in offlineGoals) {
        try {
          if (goal['_synced'] == false) {
            final goalData = Map<String, dynamic>.from(goal);
            goalData.remove('_offline');
            goalData.remove('_synced');
            goalData.remove('_modified');
            goalData.remove('id');
            
            final response = await _api.post('/financial-goals', goalData);
            if (response != null && response['data'] != null) {
              syncedGoals.add(goal);
            } else {
              failedGoals.add(goal);
            }
          } else {
            syncedGoals.add(goal);
          }
        } catch (e) {
          failedGoals.add(goal);
        }
      }
      
      // Synchroniser l'historique
      for (final history in offlineHistory) {
        try {
          if (history['_synced'] == false) {
            final historyData = Map<String, dynamic>.from(history);
            final goalId = historyData['financial_goal_id'];
            
            // Trouver l'ID du serveur pour cet objectif
            final offlineGoal = offlineGoals.firstWhere(
              (g) => g['id'] == goalId,
              orElse: () => <String, dynamic>{},
            );
            
            if (offlineGoal.isNotEmpty && offlineGoal['_server_id'] != null) {
              historyData['financial_goal_id'] = offlineGoal['_server_id'];
              historyData.remove('_offline');
              historyData.remove('_synced');
              historyData.remove('id');
              
              final response = await _api.post('/financial-goals/${offlineGoal['_server_id']}/add-amount', {
                'amount': historyData['amount'],
              });
              
              if (response != null) {
                syncedHistory.add(history);
              } else {
                failedHistory.add(history);
              }
            } else {
              failedHistory.add(history);
            }
          } else {
            syncedHistory.add(history);
          }
        } catch (e) {
          failedHistory.add(history);
        }
      }
      
      // Sauvegarder seulement les éléments échoués
      await _saveOfflineGoals(failedGoals);
      await _saveOfflineGoalHistory(failedHistory);
      
      // Notifier l'utilisateur
      if (syncedGoals.isNotEmpty || syncedHistory.isNotEmpty) {
        await NotificationService().showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'Synchronisation terminée',
          body: '${syncedGoals.length} objectif(s) et ${syncedHistory.length} ajout(s) synchronisé(s)',
          severity: 'success',
        );
      }
    } catch (e) {
      // Erreur silencieuse, on réessaiera au prochain démarrage
    } finally {
      _isSyncing = false;
    }
  }

  /// Récupère tous les objectifs (locaux + serveur)
  Future<List<Map<String, dynamic>>> getAllGoals() async {
    try {
      await _api.init();
      
      if (_api.isAuthenticated) {
        final response = await _api.get('/financial-goals');
        final serverGoals = response is Map && response['data'] is List 
            ? List<Map<String, dynamic>>.from(response['data'])
            : response is List 
                ? List<Map<String, dynamic>>.from(response)
                : <Map<String, dynamic>>[];
        
        final offlineGoals = await _getOfflineGoals();
        
        // Fusionner les objectifs (les locaux en premier)
        return [...offlineGoals, ...serverGoals];
      } else {
        return await _getOfflineGoals();
      }
    } catch (e) {
      return await _getOfflineGoals();
    }
  }

  /// Récupère l'historique d'un objectif
  Future<List<Map<String, dynamic>>> getGoalHistory(int goalId) async {
    try {
      await _api.init();
      
      if (_api.isAuthenticated) {
        final response = await _api.get('/financial-goals/$goalId/history');
        final serverHistory = response is Map && response['data'] is List
            ? List<Map<String, dynamic>>.from(response['data'])
            : response is List
                ? List<Map<String, dynamic>>.from(response)
                : <Map<String, dynamic>>[];
        
        final offlineHistory = await _getOfflineGoalHistory();
        final goalOfflineHistory = offlineHistory
            .where((h) => h['financial_goal_id'] == goalId)
            .toList();
        
        // Fusionner l'historique
        return [...goalOfflineHistory, ...serverHistory];
      } else {
        final offlineHistory = await _getOfflineGoalHistory();
        return offlineHistory.where((h) => h['financial_goal_id'] == goalId).toList();
      }
    } catch (e) {
      final offlineHistory = await _getOfflineGoalHistory();
      return offlineHistory.where((h) => h['financial_goal_id'] == goalId).toList();
    }
  }

  /// Vide toutes les données hors ligne
  Future<void> clearOfflineData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_goalsKey);
    await prefs.remove(_goalHistoryKey);
  }

  /// Compte le nombre d'éléments hors ligne
  Future<int> getOfflineCount() async {
    final offlineGoals = await _getOfflineGoals();
    final offlineHistory = await _getOfflineGoalHistory();
    return offlineGoals.length + offlineHistory.length;
  }
}
