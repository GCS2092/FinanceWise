import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  static const int _maxQueueSize = 100;
  static const Duration _maxAge = Duration(days: 7);

  Future<SharedPreferences> get prefs async {
    return SharedPreferences.getInstance();
  }

  // Ajouter une requête à la file d'attente
  Future<void> addRequest({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
  }) async {
    final p = await prefs;

    final request = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'method': method,
      'endpoint': endpoint,
      'body': body,
      'timestamp': DateTime.now().toIso8601String(),
    };

    List<dynamic> queue = await getQueue();

    // Purge des requêtes trop anciennes
    await _purgeOldRequests();

    // Si la queue est pleine, supprimer la plus ancienne (FIFO)
    if (queue.length >= _maxQueueSize) {
      queue.removeAt(0);
    }

    queue.add(request);

    await p.setString('offline_queue', jsonEncode(queue));
  }

  // Purger les requêtes plus vieilles que 7 jours
  Future<void> _purgeOldRequests() async {
    final p = await prefs;
    List<dynamic> queue = await getQueue();
    final now = DateTime.now();

    queue.removeWhere((request) {
      final timestamp = DateTime.tryParse(request['timestamp'] as String? ?? '');
      if (timestamp == null) return true;
      return now.difference(timestamp) > _maxAge;
    });

    await p.setString('offline_queue', jsonEncode(queue));
  }

  // Récupérer la file d'attente
  Future<List<dynamic>> getQueue() async {
    final p = await prefs;
    final queueJson = p.getString('offline_queue');
    if (queueJson != null) {
      return jsonDecode(queueJson);
    }
    return [];
  }

  // Supprimer une requête de la file d'attente
  Future<void> removeRequest(String id) async {
    final p = await prefs;
    List<dynamic> queue = await getQueue();
    queue.removeWhere((r) => r['id'] == id);
    await p.setString('offline_queue', jsonEncode(queue));
  }

  // Vider la file d'attente
  Future<void> clearQueue() async {
    final p = await prefs;
    await p.remove('offline_queue');
  }

  // Obtenir le nombre de requêtes en attente
  Future<int> getQueueCount() async {
    final queue = await getQueue();
    return queue.length;
  }
}
