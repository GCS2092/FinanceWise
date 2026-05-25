import 'package:shared_preferences/shared_preferences.dart';
import '../services/server_discovery_service.dart';

class AppConstants {
  // ┌─────────────────────────────────────────────┐
  // │  CONFIGURATION IP BACKEND                   │
  // └─────────────────────────────────────────────┘

  static const String _defaultApiHost = '10.0.2.2';
  static String _baseUrl = 'http://$_defaultApiHost:8000/api';

  static String get baseUrl => _baseUrl;

  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String serverUrlKey = 'server_url';

  /// Appelé au démarrage dans main() pour détecter/charger l'URL du serveur.
  static Future<void> init() async {
    // 1. URL sauvegardée manuellement par l'utilisateur
    final savedUrl = await ServerDiscoveryService.getSavedUrl();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl;
      return;
    }

    // 2. Découverte automatique du serveur sur le réseau local
    final discoveredUrl = await ServerDiscoveryService.discover();
    if (discoveredUrl != null && discoveredUrl.isNotEmpty) {
      _baseUrl = discoveredUrl;
    }
  }

  /// Met à jour l'URL et la persiste pour les prochains démarrages.
  static Future<void> updateBaseUrl(String newUrl) async {
    _baseUrl = newUrl;
    await ServerDiscoveryService.saveUrl(newUrl);
  }

  /// Remet l'URL par défaut et supprime la sauvegarde.
  static Future<void> clearSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(serverUrlKey);
    _baseUrl = 'http://$_defaultApiHost:8000/api';
  }
}