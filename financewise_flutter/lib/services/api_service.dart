import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../models/user.dart';
import 'server_discovery_service.dart';
import 'offline_cache_service.dart';
import 'offline_queue_service.dart';
import 'connectivity_service.dart';
import 'logger_service.dart';

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

  static const Duration _requestTimeout = Duration(seconds: 5);

  String? _token;
  String? _baseUrl;
  final OfflineCacheService _cache = OfflineCacheService();
  final OfflineQueueService _queue = OfflineQueueService();
  final ConnectivityService _connectivity = ConnectivityService();

  void Function()? onSessionExpired;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AppConstants.tokenKey);

    _baseUrl = prefs.getString(AppConstants.serverUrlKey);

    if (_baseUrl == null) {
      try {
        final discoveredUrl = await ServerDiscoveryService.discover()
            .timeout(const Duration(seconds: 3), onTimeout: () => null);
        _baseUrl = discoveredUrl ?? AppConstants.baseUrl;
      } catch (_) {
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
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': password,
        }),
      ).timeout(_requestTimeout);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        await setToken(data['token']);
        return data;
      }
      return _handleError(response);
    } on TimeoutException {
      return {'message': 'Délai dépassé. Vérifiez votre connexion.'};
    } catch (_) {
      return {'message': 'Erreur de connexion au serveur.'};
    }
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await setToken(data['token']);
        return data;
      }
      return _handleError(response);
    } on TimeoutException {
      return {'message': 'Délai dépassé. Vérifiez votre connexion.'};
    } catch (_) {
      return {'message': 'Erreur de connexion au serveur.'};
    }
  }

  Future<bool> logout() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/logout'),
        headers: _headers,
      ).timeout(_requestTimeout);
      await clearToken();
      return response.statusCode == 200;
    } catch (_) {
      await clearToken();
      return false;
    }
  }

  Future<User?> getUser() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user'),
        headers: _headers,
      ).timeout(_requestTimeout);
      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ─── GENERIC GET / POST / PUT / DELETE ─────────

  Future<dynamic> get(String endpoint) async {
    final isOnline = await _connectivity.isConnected;

    if (!isOnline) {
      if (endpoint.contains('/transactions')) {
        final isValid = await _cache.isCacheValid('transactions');
        if (isValid) {
          final cached = await _cache.getCachedTransactions();
          if (cached.isNotEmpty) return {'data': cached, '_offline': true};
        }
      } else if (endpoint.contains('/dashboard')) {
        final isValid = await _cache.isCacheValid('dashboard');
        if (isValid) {
          final cached = await _cache.getCachedDashboard();
          if (cached != null) return {'data': cached, '_offline': true};
        }
      } else if (endpoint.contains('/budgets')) {
        final isValid = await _cache.isCacheValid('budgets');
        if (isValid) {
          final cached = await _cache.getCachedBudgets();
          if (cached.isNotEmpty) return {'data': cached, '_offline': true};
        }
      } else if (endpoint.contains('/financial-goals')) {
        final isValid = await _cache.isCacheValid('goals');
        if (isValid) {
          final cached = await _cache.getCachedFinancialGoals();
          if (cached.isNotEmpty) return {'data': cached, '_offline': true};
        }
      }
      return {'message': 'Mode hors ligne - données non disponibles ou expirées', '_offline': true};
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
      ).timeout(_requestTimeout);
      final result = _parse(response);

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
    } on TimeoutException {
      return {'message': 'Délai dépassé.', '_timeout': true};
    } catch (_) {
      return {'message': 'Erreur réseau.', '_network_error': true};
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final isOnline = await _connectivity.isConnected;

    if (!isOnline) {
      await _queue.addRequest(method: 'POST', endpoint: endpoint, body: body);
      return {'message': 'Requête enregistrée - sera synchronisée lors de la reconnexion', '_offline': true};
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(_requestTimeout);
      return _parse(response);
    } on TimeoutException {
      return {'message': 'Délai dépassé.', '_timeout': true};
    } catch (_) {
      return {'message': 'Erreur réseau.', '_network_error': true};
    }
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final isOnline = await _connectivity.isConnected;

    if (!isOnline) {
      await _queue.addRequest(method: 'PUT', endpoint: endpoint, body: body);
      return {'message': 'Requête enregistrée - sera synchronisée lors de la reconnexion', '_offline': true};
    }

    try {
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(_requestTimeout);
      return _parse(response);
    } on TimeoutException {
      return {'message': 'Délai dépassé.', '_timeout': true};
    } catch (_) {
      return {'message': 'Erreur réseau.', '_network_error': true};
    }
  }

  Future<dynamic> delete(String endpoint) async {
    final isOnline = await _connectivity.isConnected;

    if (!isOnline) {
      await _queue.addRequest(method: 'DELETE', endpoint: endpoint);
      return {'message': 'Requête enregistrée - sera synchronisée lors de la reconnexion', '_offline': true};
    }

    try {
      final url = '$baseUrl$endpoint';
      LoggerService().debug('DELETE appel: $url');
      final response = await http.delete(
        Uri.parse(url),
        headers: _headers,
      ).timeout(_requestTimeout);
      LoggerService().debug('DELETE response: ${response.statusCode}');
      return _parse(response);
    } on TimeoutException {
      return {'message': 'Délai dépassé.', '_timeout': true};
    } catch (_) {
      return {'message': 'Erreur réseau.', '_network_error': true};
    }
  }

  // ─── HELPERS ──────────────────────────────────

  dynamic _parse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body.isNotEmpty ? jsonDecode(response.body) : null;
    }

    if (response.statusCode >= 500) {
      final body = _tryDecode(response.body);
      final message = body?['message'] ?? body?['error'] ?? 'Erreur serveur. Veuillez réessayer.';
      return {'message': message, '_server_error': true};
    }

    if (response.statusCode == 401) {
      _handleSessionExpired();
      return {'message': 'Session expirée. Veuillez vous reconnecter.', '_expired': true};
    }

    if (response.statusCode == 429) {
      final body = _tryDecode(response.body);
      final message = body?['message'] ?? 'Trop de requêtes. Réessayez dans quelques instants.';
      return {'message': message, '_rate_limited': true};
    }

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