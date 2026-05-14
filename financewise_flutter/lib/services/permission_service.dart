import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'logger_service.dart';
import 'sms_listener_service.dart';

/// Permissions runtime SMS + notifications (Android 6+ / 13+) avec logs structurés.
class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  final LoggerService _log = LoggerService();

  /// Demande SMS + notifications ; optionnellement explique et propose les réglages.
  Future<void> ensureSmsAndNotificationsForDetection(BuildContext context) async {
    _log.debug('[SMS_RECEIVED] PermissionService: début vérification SMS + notifications');

    var smsStatus = await Permission.sms.status;
    _log.debug('[SMS_RECEIVED] PermissionService: SMS status=$smsStatus');

    if (smsStatus.isDenied || smsStatus.isRestricted) {
      smsStatus = await Permission.sms.request();
      _log.debug('[SMS_RECEIVED] PermissionService: SMS après request=$smsStatus');
    }

    if (smsStatus.isPermanentlyDenied && context.mounted) {
      await _offerOpenSettings(
        context,
        title: 'Permission SMS requise',
        message:
            'FinanceWise a besoin de lire les SMS de paiement (Wave, Orange Money, etc.) pour proposer des transactions. '
            'Ouvrez les paramètres et accordez « SMS ».',
      );
    }

    final notifStatus = await Permission.notification.status;
    _log.debug('[SMS_RECEIVED] PermissionService: notification status=$notifStatus');

    if (notifStatus.isDenied || notifStatus.isRestricted) {
      final after = await Permission.notification.request();
      _log.debug('[SMS_RECEIVED] PermissionService: notification après request=$after');
    }

    if (context.mounted) {
      final nativeOk = await SmsListenerService.checkSmsPermission();
      _log.debug('[SMS_RECEIVED] PermissionService: checkSmsPermission natif=$nativeOk');
    }
  }

  Future<void> _offerOpenSettings(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Plus tard')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            child: const Text('Ouvrir les paramètres'),
          ),
        ],
      ),
    );
  }
}
