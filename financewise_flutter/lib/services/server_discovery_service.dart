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
    
    // Vérifier les propriétés système via Process.run
    try {
      final result = await Process.run('getprop', ['ro.build.characteristics']);
      final output = (result.stdout as String).toLowerCase();
      if (output.contains('emulator') || output.contains('generic')) return true;
      
      final modelResult = await Process.run('getprop', ['ro.product.model']);
      final model = (modelResult.stdout as String).toLowerCase();
      if (model.contains('emulator') || model.contains('sdk_gphone') || model.contains('sdk')) return true;
      
      final manufacturerResult = await Process.run('getprop', ['ro.product.manufacturer']);
      final manufacturer = (manufacturerResult.stdout as String).toLowerCase();
      if (manufacturer.contains('google') && model.contains('sdk')) return true;
    } catch (_) {
      // En cas d'erreur, on assume que c'est un appareil physique
    }
    
    return false;
  }
}
