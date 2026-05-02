import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

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
    queue.add(request);
    
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
