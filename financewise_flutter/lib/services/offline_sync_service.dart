import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_service.dart';
import 'offline_queue_service.dart';
import 'offline_cache_service.dart';

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  final ApiService _api = ApiService();
  final OfflineQueueService _queue = OfflineQueueService();
  final OfflineCacheService _cache = OfflineCacheService();
  final Connectivity _connectivity = Connectivity();

  bool _isSyncing = false;

  // Écouter les changements de connexion
  void startListening() {
    _connectivity.onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none && !_isSyncing) {
        await syncQueue();
      }
    });
  }

  // Synchroniser la file d'attente
  Future<void> syncQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final queue = await _queue.getQueue();
      
      for (var request in queue) {
        try {
          final method = request['method'];
          final endpoint = request['endpoint'];
          final body = request['body'];
          
          dynamic response;
          switch (method) {
            case 'POST':
              response = await _api.post(endpoint, body);
              break;
            case 'PUT':
              response = await _api.put(endpoint, body);
              break;
            case 'DELETE':
              response = await _api.delete(endpoint);
              break;
          }
          
          // Si succès, supprimer de la queue
          if (response != null && !(response is Map && response.containsKey('_offline'))) {
            await _queue.removeRequest(request['id']);
          }
        } catch (e) {
          print('Erreur sync: $e');
        }
      }
      
      // Rafraîchir le cache après sync
      await refreshCache();
    } finally {
      _isSyncing = false;
    }
  }

  // Rafraîchir le cache
  Future<void> refreshCache() async {
    try {
      await _api.get('/transactions');
      await _api.get('/dashboard');
      await _api.get('/budgets');
      await _api.get('/financial-goals');
    } catch (e) {
      print('Erreur refresh cache: $e');
    }
  }

  // Obtenir le nombre d'éléments en attente
  Future<int> getPendingCount() async {
    return await _queue.getQueueCount();
  }
}
