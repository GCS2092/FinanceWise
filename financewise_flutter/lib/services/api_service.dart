import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/user.dart';
import 'server_discovery_service.dart';
import 'offline_cache_service.dart';
import 'offline_queue_service.dart';
import 'connectivity_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;
  String? _baseUrl;
  final OfflineCacheService _cache = OfflineCacheService();
  final OfflineQueueService _queue = OfflineQueueService();
  final ConnectivityService _connectivity = ConnectivityService();

  // Callback déclenché quand le token est expiré (401)
  void Function()? onSessionExpired;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AppConstants.tokenKey);
    
    // Essayer de récupérer l'URL sauvegardée
    _baseUrl = prefs.getString(AppConstants.serverUrlKey);
    
    // Si pas d'URL sauvegardée, tenter la découverte automatique
    if (_baseUrl == null) {
      final discoveredUrl = await ServerDiscoveryService.discover();
      if (discoveredUrl != null) {
        _baseUrl = discoveredUrl;
      } else {
        // Fallback sur l'URL par défaut
        _baseUrl = AppConstants.baseUrl;
      }
    }
  }

  String get baseUrl => _baseUrl ?? AppConstants.baseUrl;

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.serverUrlKey, url);
  }

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
  }

  bool get isAuthenticated => _token != null;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ─── AUTH ─────────────────────────────────────

  Future<Map<String, dynamic>?> register(String name, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': password,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      await setToken(data['token']);
      return data;
    }
    return _handleError(response);
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await setToken(data['token']);
      return data;
    }
    return _handleError(response);
  }

  Future<bool> logout() async {
    final response = await http.post(
      Uri.parse('$baseUrl/logout'),
      headers: _headers,
    );
    await clearToken();
    return response.statusCode == 200;
  }

  Future<User?> getUser() async {
    final response = await http.get(
      Uri.parse('$baseUrl/user'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    }
    return null;
  }

  // ─── GENERIC GET / POST / PUT / DELETE ─────────

  Future<dynamic> get(String endpoint) async {
    final isOnline = await _connectivity.isConnected;
    
    if (!isOnline) {
      // Mode offline - essayer de retourner du cache
      if (endpoint.contains('/transactions')) {
        final cached = await _cache.getCachedTransactions();
        if (cached.isNotEmpty) return {'data': cached, '_offline': true};
      } else if (endpoint.contains('/dashboard')) {
        final cached = await _cache.getCachedDashboard();
        if (cached != null) return {'data': cached, '_offline': true};
      } else if (endpoint.contains('/budgets')) {
        final cached = await _cache.getCachedBudgets();
        if (cached.isNotEmpty) return {'data': cached, '_offline': true};
      } else if (endpoint.contains('/financial-goals')) {
        final cached = await _cache.getCachedFinancialGoals();
        if (cached.isNotEmpty) return {'data': cached, '_offline': true};
      }
      return {'message': 'Mode hors ligne - données non disponibles', '_offline': true};
    }
    
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers,
    );
    final result = _parse(response);
    
    // Mettre en cache si succès
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (endpoint.contains('/transactions')) {
        final data = result is Map ? result['data'] : result;
        if (data is List) await _cache.cacheTransactions(data);
      } else if (endpoint.contains('/dashboard')) {
        if (result is Map) await _cache.cacheDashboard(Map<String, dynamic>.from(result));
      } else if (endpoint.contains('/budgets')) {
        final data = result is Map ? result['data'] : result;
        if (data is List) await _cache.cacheBudgets(data);
      } else if (endpoint.contains('/financial-goals')) {
        final data = result is Map ? result['data'] : result;
        if (data is List) await _cache.cacheFinancialGoals(data);
      }
    }
    
    return result;
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final isOnline = await _connectivity.isConnected;
    
    if (!isOnline) {
      // Mode offline - ajouter à la queue
      await _queue.addRequest(method: 'POST', endpoint: endpoint, body: body);
      return {'message': 'Requête enregistrée - sera synchronisée lors de la reconnexion', '_offline': true};
    }
    
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _parse(response);
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final isOnline = await _connectivity.isConnected;
    
    if (!isOnline) {
      // Mode offline - ajouter à la queue
      await _queue.addRequest(method: 'PUT', endpoint: endpoint, body: body);
      return {'message': 'Requête enregistrée - sera synchronisée lors de la reconnexion', '_offline': true};
    }
    
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _parse(response);
  }

  Future<dynamic> delete(String endpoint) async {
    final isOnline = await _connectivity.isConnected;
    
    if (!isOnline) {
      // Mode offline - ajouter à la queue
      await _queue.addRequest(method: 'DELETE', endpoint: endpoint);
      return {'message': 'Requête enregistrée - sera synchronisée lors de la reconnexion', '_offline': true};
    }
    
    final url = '$baseUrl$endpoint';
    print('DELETE appel: $url');
    final response = await http.delete(
      Uri.parse(url),
      headers: _headers,
    );
    print('DELETE response: ${response.statusCode}');
    return _parse(response);
  }

  // ─── HELPERS ──────────────────────────────────

  dynamic _parse(http.Response response) {
    // Succès (200, 201, 202, etc.)
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body.isNotEmpty ? jsonDecode(response.body) : null;
    }

    // Erreurs serveur (500, 502, 503, etc.)
    if (response.statusCode >= 500) {
      final body = _tryDecode(response.body);
      final message = body?['message'] ?? body?['error'] ?? 'Erreur serveur. Veuillez réessayer.';
      return {'message': message, '_server_error': true};
    }

    // Token expiré ou invalide → ne pas déconnecter automatiquement (connexion persistante)
    if (response.statusCode == 401) {
      // _handleSessionExpired();
      return {'message': 'Session expirée. Veuillez vous reconnecter.', '_expired': true};
    }

    // Rate limit dépassé
    if (response.statusCode == 429) {
      final body = _tryDecode(response.body);
      final message = body?['message'] ?? 'Trop de requêtes. Réessayez dans quelques instants.';
      return {'message': message, '_rate_limited': true};
    }

    // Conflit (ex: suppression wallet avec transactions)
    if (response.statusCode == 409) {
      final body = _tryDecode(response.body);
      final message = body?['message'] ?? 'Action impossible : ressource en cours d\'utilisation.';
      return {'message': message, '_conflict': true};
    }

    return _handleError(response);
  }

  Map<String, dynamic>? _handleError(http.Response response) {
    final body = _tryDecode(response.body);
    if (body != null) return body;
    return {'message': 'Erreur serveur (${response.statusCode})'};
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void _handleSessionExpired() {
    clearToken();
    onSessionExpired?.call();
  }
}
