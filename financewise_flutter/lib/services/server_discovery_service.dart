import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServerDiscoveryService {
  static const String _savedUrlKey = 'saved_server_url';

  /// Récupère l'URL sauvegardée si elle existe
  static Future<String?> getSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_savedUrlKey);
  }

  /// Sauvegarde une URL manuelle
  static Future<void> saveUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedUrlKey, url);
  }

  /// Détecte automatiquement le serveur backend
  static Future<String?> discover() async {
    // 1. Émulateur Android
    if (await _isEmulator()) {
      final url = 'http://10.0.2.2:8000/api';
      if (await _isServerAlive(url)) return url;
    }

    // 2. Simulateur iOS
    if (Platform.isIOS) {
      final url = 'http://127.0.0.1:8000/api';
      if (await _isServerAlive(url)) return url;
    }

    // 3. Téléphone physique — scanner le subnet WiFi
    final wifiIp = await NetworkInfo().getWifiIP();
    if (wifiIp != null) {
      final subnet = wifiIp.substring(0, wifiIp.lastIndexOf('.'));
      
      // Scanner les 20 premières IPs du subnet (habituellement le PC est .1 à .20)
      for (int i = 1; i <= 20; i++) {
        final candidate = 'http://$subnet.$i:8000/api';
        if (await _isServerAlive(candidate, timeout: const Duration(milliseconds: 800))) {
          await saveUrl(candidate);
          return candidate;
        }
      }
    }

    return null;
  }

  /// Vérifie si le serveur répond à /login (ou n'importe quel endpoint)
  static Future<bool> _isServerAlive(String baseUrl, {Duration timeout = const Duration(seconds: 2)}) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/user'), headers: {'Accept': 'application/json'})
          .timeout(timeout);
      // 401 = serveur Laravel actif mais pas authentifié
      // 200 = OK
      return response.statusCode == 200 || response.statusCode == 401 || response.statusCode == 404;
    } catch (_) {
      return false;
    }
  }

  /// Détection émulateur Android (heuristique simple)
  static Future<bool> _isEmulator() async {
    if (!Platform.isAndroid) return false;
    final fingerprint = await _getProp('ro.build.fingerprint');
    final model = await _getProp('ro.product.model');
    final manufacturer = await _getProp('ro.product.manufacturer');
    final hardware = await _getProp('ro.hardware');

    return (fingerprint?.contains('generic') ?? false) ||
           (fingerprint?.contains('emulator') ?? false) ||
           (model?.contains('Emulator') ?? false) ||
           (model?.contains('sdk') ?? false) ||
           (manufacturer?.contains('Google') ?? false) ||
           (hardware?.contains('goldfish') ?? false) ||
           (hardware?.contains('ranchu') ?? false);
  }

  static Future<String?> _getProp(String prop) async {
    try {
      if (!Platform.isAndroid) return null;
      // Utiliser les propriétés système via Platform
      return null; // Simplifié : on peut améliorer plus tard
    } catch (_) {
      return null;
    }
  }
}
