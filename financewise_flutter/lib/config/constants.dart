class AppConstants {
  // ┌─────────────────────────────────────────────┐
  // │  CONFIGURATION IP BACKEND                   │
  // │                                              │
  // │  • Émulateur Android  →  10.0.2.2           │
  // │  • Simulateur iOS     →  127.0.0.1          │
  // │  • Téléphone physique →  IP WiFi du PC      │
  // │    (Ex: 192.168.1.42 — voir ipconfig)       │
  // │                                              │
  // │  L'application détecte automatiquement      │
  // │  le serveur au démarrage. Cette IP est     │
  // │  utilisée uniquement en fallback.          │
  // └─────────────────────────────────────────────┘
  static const String _defaultApiHost = '192.168.1.4'; // Fallback si détection échoue

  static String get baseUrl => 'http://$_defaultApiHost:8000/api';

  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String serverUrlKey = 'server_url';
}
