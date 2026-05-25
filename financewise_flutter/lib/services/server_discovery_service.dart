import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
   return 'http://10.0.2.2:8000/api';
  }

  /// Vérifie si le serveur répond à /login (ou n'importe quel endpoint)
  static Future<bool> _isServerAlive(String baseUrl, {Duration timeout = const Duration(seconds: 2)}) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/user'), headers: {'Accept': 'application/json'})
          .timeout(timeout);

      // 401 = serveur Laravel actif mais pas authentifié
      // 200 = OK
      return response.statusCode == 200 ||
          response.statusCode == 401 ||
          response.statusCode == 404;
    } catch (_) {
      return false;
    }
  }

  /// Détection émulateur Android (heuristique simple)
  static Future<bool> _isEmulator() async {
    if (kIsWeb) return false;
    if (!Platform.isAndroid) return false;

    // Vérifier les propriétés système via Process.run
    try {
      final result =
          await Process.run('getprop', ['ro.build.characteristics']);

      final output = (result.stdout as String).toLowerCase();

      if (output.contains('emulator') || output.contains('generic')) {
        return true;
      }

      final modelResult =
          await Process.run('getprop', ['ro.product.model']);

      final model = (modelResult.stdout as String).toLowerCase();

      if (model.contains('emulator') ||
          model.contains('sdk_gphone') ||
          model.contains('sdk')) {
        return true;
      }

      final manufacturerResult =
          await Process.run('getprop', ['ro.product.manufacturer']);

      final manufacturer =
          (manufacturerResult.stdout as String).toLowerCase();

      if (manufacturer.contains('google') && model.contains('sdk')) {
        return true;
      }
    } catch (_) {
      // En cas d'erreur, on assume que c'est un appareil physique
    }

    return false;
  }
}