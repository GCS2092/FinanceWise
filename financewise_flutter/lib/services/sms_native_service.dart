import 'package:permission_handler/permission_handler.dart';

import 'auto_transaction_service.dart';
import 'logger_service.dart';

/// Paramètres « envoi auto au backend » + demande SMS si l’auto est activée.
/// L’écoute MethodChannel est centralisée dans [SmsListenerService] (plus d’écrasement ici).
class SmsNativeService {
  static final SmsNativeService _instance = SmsNativeService._internal();
  factory SmsNativeService() => _instance;
  SmsNativeService._internal();

  final AutoTransactionService _autoService = AutoTransactionService();
  final LoggerService _log = LoggerService();

  Future<void> initialize() async {
    await _autoService.loadSettings();
    _log.debug('[SMS_RECEIVED] SmsNativeService.initialize auto=${_autoService.isEnabled}');

    if (!_autoService.isEnabled) return;

    final status = await Permission.sms.request();
    _log.debug('[SMS_RECEIVED] SmsNativeService Permission.sms.request => $status');
  }

  /// Conservé pour compatibilité avec [HomeScreen.dispose] ; le canal est géré par [SmsListenerService].
  void stopListening() {
    _log.debug('[FLUTTER_SMS_RECEIVED] SmsNativeService.stopListening (noop)');
  }
}
