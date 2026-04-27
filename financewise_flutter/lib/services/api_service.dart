import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/user.dart';

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

  // Callback déclenché quand le token est expiré (401)
  void Function()? onSessionExpired;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AppConstants.tokenKey);
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
      Uri.parse('${AppConstants.baseUrl}/register'),
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
      Uri.parse('${AppConstants.baseUrl}/login'),
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
      Uri.parse('${AppConstants.baseUrl}/logout'),
      headers: _headers,
    );
    await clearToken();
    return response.statusCode == 200;
  }

  Future<User?> getUser() async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/user'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    }
    return null;
  }

  // ─── GENERIC GET / POST / PUT / DELETE ─────────

  Future<dynamic> get(String endpoint) async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}$endpoint'),
      headers: _headers,
    );
    return _parse(response);
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}$endpoint'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _parse(response);
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('${AppConstants.baseUrl}$endpoint'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _parse(response);
  }

  Future<dynamic> delete(String endpoint) async {
    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}$endpoint'),
      headers: _headers,
    );
    return _parse(response);
  }

  // ─── HELPERS ──────────────────────────────────

  dynamic _parse(http.Response response) {
    // Succès (200, 201, 202, etc.)
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body.isNotEmpty ? jsonDecode(response.body) : null;
    }

    // Token expiré ou invalide → déconnexion automatique
    if (response.statusCode == 401) {
      _handleSessionExpired();
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
