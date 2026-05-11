import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'services/biometric_service.dart';
import 'services/notification_service.dart';
import 'services/api_service.dart';
import 'services/offline_sync_service.dart';
import 'services/sms_listener_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'config/router.dart';
import 'theme.dart';

class FadePageRoute extends PageRouteBuilder {
  final Widget child;

  FadePageRoute({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;

            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser les locales pour DateFormat (fr_FR)
  await initializeDateFormatting('fr_FR', null);
  
  // Initialiser le service de notifications
  await NotificationService().initialize();
  await NotificationService().requestPermissions();
  
  // Initialiser le service de sync offline
  OfflineSyncService().startListening();
  
  // Initialiser le MethodChannel SMS pour les notifications
  _initSmsMethodChannel();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const AppInitializer(),
    ),
  );
}

void _initSmsMethodChannel() {
  const channel = MethodChannel('com.example.financewise_flutter/sms');
  channel.setMethodCallHandler((call) async {
    if (call.method == 'onSmsActionAdd') {
      print('=== onSmsActionAdd (global) ===');
      final smsData = call.arguments as Map<dynamic, dynamic>;
      final sender = smsData['sender'] as String;
      final body = smsData['body'] as String;
      print('Sender: $sender');
      print('Body: $body');
      // Stocker le SMS en attente pour traitement ultérieur
      // Le traitement sera fait quand le dashboard sera initialisé
    }
  });
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();
    // Vérifier l'authentification au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().checkAuth();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp.router(
          title: 'FinanceWise',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          routerConfig: router,
        );
      },
    );
  }

  Future<bool> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final api = ApiService();
    
    // Essayer d'abord depuis l'API (source de vérité)
    try {
      await api.init();
      if (api.isAuthenticated) {
        final result = await api.get('/user/onboarding/status');
        if (result is Map && result.containsKey('onboarding_completed')) {
          final apiStatus = result['onboarding_completed'] as bool;
          // Synchroniser avec SharedPreferences
          await prefs.setBool('onboarding_completed', apiStatus);
          return apiStatus;
        }
      }
    } catch (e) {
      // En cas d'erreur, utiliser SharedPreferences comme fallback
    }
    
    // Fallback sur SharedPreferences
    return prefs.getBool('onboarding_completed') ?? false;
  }
}

class BiometricCheckScreen extends StatefulWidget {
  final Widget child;
  const BiometricCheckScreen({super.key, required this.child});

  @override
  State<BiometricCheckScreen> createState() => _BiometricCheckScreenState();
}

class _BiometricCheckScreenState extends State<BiometricCheckScreen> {
  final BiometricService _bioService = BiometricService();
  bool _authenticated = false;
  DateTime? _lastAuthTime;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    final biometricActivated = prefs.getBool('biometric_activated') ?? false;
    final hasBio = await _bioService.hasBiometrics();
    final lastAuthTime = prefs.getInt('last_biometric_auth_time');

    // Vérifier si l'authentification a été faite il y a moins de 5 minutes
    // Si oui, ne pas redemander (évite de demander à chaque resume)
    bool recentAuth = false;
    if (lastAuthTime != null) {
      final lastAuth = DateTime.fromMillisecondsSinceEpoch(lastAuthTime);
      final difference = DateTime.now().difference(lastAuth);
      recentAuth = difference.inMinutes < 5;
    }

    if (biometricActivated && hasBio && !recentAuth) {
      final authenticated = await _bioService.authenticate();
      if (authenticated && mounted) {
        await prefs.setInt('last_biometric_auth_time', DateTime.now().millisecondsSinceEpoch);
        setState(() => _authenticated = true);
      } else if (mounted) {
        setState(() => _authenticated = false);
      }
    } else {
      setState(() => _authenticated = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_authenticated) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Authentification biométrique requise'),
            ],
          ),
        ),
      );
    }
    return widget.child;
  }
}
