import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/sms_confirmation_dialog.dart';
import '../theme.dart';
import 'api_service.dart';
import 'auto_transaction_service.dart';
import 'logger_service.dart';
import 'sms_parser_service.dart';

/// Écoute unique du MethodChannel SMS (évite les écrasements entre services).
class SmsListenerService {
  static const _channel = MethodChannel('com.example.financewise_flutter/sms');
  static SmsListenerService? _instance;
  final BuildContext _context;
  final VoidCallback? _onTransactionAdded;
  final SmsParserService _parserService = SmsParserService();
  final AutoTransactionService _autoService = AutoTransactionService();
  final ApiService _api = ApiService();
  final LoggerService _log = LoggerService();

  static String? _lastProcessedSms;
  static DateTime? _lastProcessedTime;

  SmsListenerService._({
    required BuildContext context,
    VoidCallback? onTransactionAdded,
  })  : _context = context,
        _onTransactionAdded = onTransactionAdded {
    _loadWallets();
  }

  List<dynamic> _wallets = [];
  String? _defaultWalletId;

  static const Map<String, String> _keywordToWalletType = {
    'yango': 'transport',
    'taxi': 'transport',
    'bus': 'transport',
    'car': 'transport',
    'véhicule': 'transport',
    'transport': 'transport',
    'essence': 'transport',
    'carburant': 'transport',
    'gazoil': 'transport',
    'boutiquier': 'alimentation',
    'restaurant': 'alimentation',
    'café': 'alimentation',
    'fast food': 'alimentation',
    'snack': 'alimentation',
    'manger': 'alimentation',
    'repas': 'alimentation',
    'food': 'alimentation',
    'aliment': 'alimentation',
    'supermarché': 'alimentation',
    'market': 'alimentation',
    'orange': 'téléphone',
    'wave': 'téléphone',
    'free': 'téléphone',
    'expresso': 'téléphone',
    'internet': 'téléphone',
    'data': 'téléphone',
    'appel': 'téléphone',
    'sms': 'téléphone',
    'credit': 'téléphone',
    'cash': 'espèces',
    'espèces': 'espèces',
    'argent': 'espèces',
    'retrait': 'espèces',
    'banque': 'banque',
    'cb': 'banque',
    'carte': 'banque',
    'virement': 'banque',
  };

  Future<void> _loadWallets() async {
    try {
      final result = await _api.get('/wallets');
      if (result is Map && result.containsKey('data')) {
        _wallets = result['data'] as List;
      } else if (result is List) {
        _wallets = result;
      }
      if (_wallets.isNotEmpty) {
        _defaultWalletId = _wallets.first['id']?.toString();
      }
    } catch (e) {
      _log.debug('[OFFLINE_QUEUE] _loadWallets error: $e');
    }
  }

  String? _selectWalletFromKeywords(String smsBody) {
    final lowerBody = smsBody.toLowerCase();
    String? walletType;
    for (final entry in _keywordToWalletType.entries) {
      if (lowerBody.contains(entry.key)) {
        walletType = entry.value;
        break;
      }
    }
    if (walletType == null) return _defaultWalletId;
    for (final wallet in _wallets) {
      final walletTypeLower = (wallet['type'] ?? '').toString().toLowerCase();
      final walletNameLower = (wallet['name'] ?? '').toString().toLowerCase();
      if (walletTypeLower.contains(walletType) || walletNameLower.contains(walletType)) {
        return wallet['id']?.toString();
      }
    }
    return _defaultWalletId;
  }

  static SmsListenerService getInstance({
    required BuildContext context,
    VoidCallback? onTransactionAdded,
  }) {
    _instance = SmsListenerService._(
      context: context,
      onTransactionAdded: onTransactionAdded,
    );
    return _instance!;
  }

  void startListening() {
    _channel.setMethodCallHandler(_handleMethodCall);
    _log.debug('[FLUTTER_SMS_RECEIVED] SmsListenerService: handler enregistré (canal unique)');
  }

  void stopListening() {
    _channel.setMethodCallHandler(null);
    _log.debug('[FLUTTER_SMS_RECEIVED] SmsListenerService: handler retiré');
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onSmsReceived':
        await _onInboundSms(call, source: 'sms_broadcast');
        break;
      case 'onBankNotification':
        await _onInboundSms(call, source: 'notification_listener');
        break;
      case 'onSmsActionAdd':
        await _onSmsActionAdd(call);
        break;
      default:
        _log.debug('[FLUTTER_SMS_RECEIVED] méthode inconnue: ${call.method}');
    }
  }

  Future<void> _onInboundSms(MethodCall call, {required String source}) async {
    try {
      final smsData = call.arguments as Map<dynamic, dynamic>;
      final sender = smsData['sender'] as String? ?? '';
      final body = smsData['body'] as String? ?? '';
      _log.debug('[FLUTTER_SMS_RECEIVED] $source sender=$sender bodyLen=${body.length}');

      await _autoService.loadSettings();
      if (_autoService.isEnabled && _context.mounted) {
        unawaited(_autoService.handleAutoSms(body, sender, _context));
        _log.debug('[TRANSACTION_DETECTED] auto backend activé — envoi parallèle');
      }

      final provider = _autoService.detectProvider(sender, body);
      if (provider == null || !_autoService.hasAmount(body)) {
        _log.debug('[TRANSACTION_DETECTED] filtre Flutter: provider=$provider hasAmount=${_autoService.hasAmount(body)}');
        return;
      }
      _log.debug('[TRANSACTION_DETECTED] candidat retenu provider=$provider');

      final transaction = await _parserService.parseSmsWithCategories(body, sender);
      if (transaction != null && _context.mounted) {
        final confirmed = await showSmsConfirmationDialog(_context, transaction);
        if (confirmed == true) {
          _onTransactionAdded?.call();
        }
        try {
          await _channel.invokeMethod('clearPendingSms');
          _log.debug('[OFFLINE_QUEUE] clearPendingSms après dialogue SMS');
        } catch (_) {}
      }
    } catch (e, st) {
      _log.error('[FLUTTER_SMS_RECEIVED] _onInboundSms error: $e', e, st);
    }
  }

  Future<void> _onSmsActionAdd(MethodCall call) async {
    try {
      final smsData = call.arguments as Map<dynamic, dynamic>;
      final sender = smsData['sender'] as String? ?? '';
      final body = smsData['body'] as String? ?? '';
      _log.debug('[FLUTTER_SMS_RECEIVED] onSmsActionAdd sender=$sender');

      final smsKey = '$sender|$body';
      final now = DateTime.now();
      if (_lastProcessedSms == smsKey &&
          _lastProcessedTime != null &&
          now.difference(_lastProcessedTime!).inSeconds < 5) {
        _log.debug('[FLUTTER_SMS_RECEIVED] doublon ignoré (<5s)');
        return;
      }
      _lastProcessedSms = smsKey;
      _lastProcessedTime = now;

      final provider = _autoService.detectProvider(sender, body);
      if (provider == null || !_autoService.hasAmount(body)) {
        _log.debug('[TRANSACTION_DETECTED] onSmsActionAdd rejeté provider=$provider');
        return;
      }

      final transaction = await _parserService.parseSmsWithCategories(body, sender);
      if (transaction == null) return;

      final walletId = _selectWalletFromKeywords(body);
      final transactionData = transaction.toJson();
      if (walletId != null) {
        transactionData['wallet_id'] = walletId;
      }

      _log.debug('[OFFLINE_QUEUE] POST /transactions depuis notification action');
      final result = await _api.post('/transactions', transactionData);

      if (result is Map<String, dynamic>) {
        if (result['_offline'] == true) {
          _log.debug('[OFFLINE_QUEUE] transaction mise en file (_offline)');
        }
        if (_context.mounted) {
          ScaffoldMessenger.of(_context).showSnackBar(
            const SnackBar(
              content: Text('Transaction ajoutée avec succès'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
        _onTransactionAdded?.call();
        await _channel.invokeMethod('clearPendingSms');
      } else {
        _log.warning('[SYNC] réponse inattendue: $result');
        if (_context.mounted) {
          ScaffoldMessenger.of(_context).showSnackBar(
            const SnackBar(
              content: Text('Erreur lors de l\'ajout de la transaction'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } catch (e, st) {
      _log.error('[FLUTTER_SMS_RECEIVED] onSmsActionAdd error: $e', e, st);
      if (_context.mounted) {
        ScaffoldMessenger.of(_context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  static Future<bool> requestSmsPermission() async {
    try {
      await _channel.invokeMethod('requestSmsPermission');
      return await checkSmsPermission();
    } catch (e) {
      return false;
    }
  }

  static Future<bool> checkSmsPermission() async {
    try {
      final result = await _channel.invokeMethod('checkSmsPermission');
      return result as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> requestNotificationPermission() async {
    try {
      await _channel.invokeMethod('requestNotificationPermission');
    } catch (_) {}
  }

  static Future<bool> checkNotificationPermission() async {
    try {
      final result = await _channel.invokeMethod('checkNotificationPermission');
      return result as bool? ?? false;
    } catch (_) {
      return false;
    }
  }
}
