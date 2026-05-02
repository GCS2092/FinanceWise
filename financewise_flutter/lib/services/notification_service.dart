import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../theme.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
      },
    );

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    // Android 13+ requires POST_NOTIFICATIONS permission
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  AndroidNotificationDetails _getAndroidDetails({
    required String severity,
    required int id,
  }) {
    // Sévérité: info, warning, danger, success
    Importance importance;
    Priority priority;
    bool enableVibration;

    switch (severity.toLowerCase()) {
      case 'danger':
        importance = Importance.max;
        priority = Priority.high;
        enableVibration = true;
        break;
      case 'warning':
        importance = Importance.high;
        priority = Priority.high;
        enableVibration = true;
        break;
      case 'success':
        importance = Importance.high;
        priority = Priority.high;
        enableVibration = true;
        break;
      default: // info
        importance = Importance.defaultImportance;
        priority = Priority.defaultPriority;
        enableVibration = false;
    }

    return AndroidNotificationDetails(
      'financewise_channel',
      'FinanceWise Notifications',
      channelDescription: 'Notifications pour FinanceWise',
      importance: importance,
      priority: priority,
      showWhen: true,
      enableVibration: enableVibration,
      playSound: true,
    );
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String severity = 'info',
  }) async {
    final androidPlatformChannelSpecifics = _getAndroidDetails(severity: severity, id: id);

    const DarwinNotificationDetails iosPlatformChannelSpecifics =
        DarwinNotificationDetails();

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );

    await _notifications.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  Future<void> showBudgetAlert(String categoryName, double spent, double limit, {String severity = 'warning'}) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Alerte Budget',
      body: 'Catégorie $categoryName: ${AppTheme.formatCurrency(spent)} / ${AppTheme.formatCurrency(limit)}',
      severity: severity,
    );
  }

  Future<void> showTransactionAlert(String message) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Nouvelle Transaction',
      body: message,
      severity: 'info',
    );
  }

  Future<void> showAlert({
    required String title,
    required String message,
    required String severity,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: message,
      severity: severity,
    );
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
