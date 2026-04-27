class AppConstants {
  // ┌─────────────────────────────────────────────┐
  // │  CONFIGURATION IP BACKEND                   │
  // │                                              │
  // │  • Émulateur Android  →  10.0.2.2           │
  // │  • Simulateur iOS     →  127.0.0.1          │
  // │  • Téléphone physique →  IP WiFi du PC      │
  // │    (Ex: 192.168.1.42 — voir ipconfig)       │
  // └─────────────────────────────────────────────┘
  static const String apiHost = '192.168.1.6';
  // static const String apiHost = '192.168.1.42'; // ← Pour téléphone physique

  static String get baseUrl => 'http://$apiHost:8000/api';

  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
}
