import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/pending_transaction_retry_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  bool _isLoading = false;
  String? _error;
  User? _user;
  bool _isAuthenticated = false;

  AuthProvider() {
    _api.onSessionExpired = _handleSessionExpired;
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  User? get user => _user;
  bool get isAuthenticated => _isAuthenticated;

  void _handleSessionExpired() {
    _isAuthenticated = false;
    _user = null;
    _error = 'Session expirée. Veuillez vous reconnecter.';
    _clearUserData();
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _api.login(email, password);
      _isLoading = false;

      if (result != null && result['token'] != null) {
        _isAuthenticated = true;
        _user = User.fromJson(result['user'] ?? {});
        await _saveUserData(result);
        await _saveLoginState(true);
        PendingTransactionRetryService().retryPendingTransactions();
        notifyListeners();
        return true;
      } else {
        _error = result?['message'] ?? 'Identifiants incorrects';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Erreur de connexion au serveur';
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _api.register(name, email, password);
      _isLoading = false;

      if (result != null && result['token'] != null) {
        _isAuthenticated = true;
        _user = User.fromJson(result['user'] ?? {});
        await _saveUserData(result);
        await _saveLoginState(true);
        PendingTransactionRetryService().retryPendingTransactions();
        notifyListeners();
        return true;
      } else {
        _error = result?['message'] ?? 'Échec de l\'inscription';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Erreur de connexion au serveur';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    _isAuthenticated = false;
    _user = null;
    _error = null;
    await _clearUserData();
    await _saveLoginState(false);
    notifyListeners();
  }

  Future<void> checkAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _api.init();
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user_data');

      if (_api.isAuthenticated && userData != null) {
        _isAuthenticated = true;
        _user = User.fromJson(jsonDecode(userData));
        await _saveLoginState(true);
        PendingTransactionRetryService().retryPendingTransactions();
      } else if (_api.isAuthenticated) {
        // Token présent mais pas de données locales → récupérer depuis l'API
        _user = await _api.getUser().timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        );
        if (_user != null) {
          _isAuthenticated = true;
          await _saveUserData({'user': _user?.toJson()});
          await _saveLoginState(true);
          PendingTransactionRetryService().retryPendingTransactions();
        }
      }
    } catch (_) {
      // En cas d'erreur réseau, rester non authentifié
      _isAuthenticated = false;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveUserData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    if (data['user'] != null) {
      await prefs.setString('user_data', jsonEncode(data['user']));
    }
  }

  Future<void> _saveLoginState(bool isLoggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', isLoggedIn);
  }

  Future<void> _clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
    await prefs.remove('is_logged_in');
  }
}