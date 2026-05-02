import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class ExpenseReminderService {
  static const String _prefsKey = 'expense_reminder_enabled';
  static const String _lastReminderKey = 'last_reminder_date';
  static const String _reminderDayKey = 'reminder_day'; // 0-6 (Lundi-Dimanche)

  static final ExpenseReminderService _instance = ExpenseReminderService._internal();
  factory ExpenseReminderService() => _instance;
  ExpenseReminderService._internal();

  /// Activer/désactiver les rappels
  Future<bool> isReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  Future<void> setReminderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
  }

  /// Définir le jour de rappel (0-6, 0 = Lundi)
  Future<int> getReminderDay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_reminderDayKey) ?? 0; // Par défaut lundi
  }

  Future<void> setReminderDay(int day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_reminderDayKey, day);
  }

  /// Vérifier si un rappel doit être envoyé aujourd'hui
  Future<bool> shouldSendReminder() async {
    final enabled = await isReminderEnabled();
    if (!enabled) return false;

    final prefs = await SharedPreferences.getInstance();
    final lastReminderStr = prefs.getString(_lastReminderKey);
    
    if (lastReminderStr == null) {
      // Premier rappel
      return true;
    }

    final lastReminder = DateTime.parse(lastReminderStr);
    final now = DateTime.now();
    final daysSinceLastReminder = now.difference(lastReminder).inDays;

    // Rappel toutes les 2 semaines (14 jours)
    return daysSinceLastReminder >= 14;
  }

  /// Envoyer le rappel si nécessaire
  Future<void> sendReminderIfNeeded() async {
    if (await shouldSendReminder()) {
      await sendReminder();
    }
  }

  /// Envoyer un rappel maintenant
  Future<void> sendReminder() async {
    final prefs = await SharedPreferences.getInstance();
    
    await NotificationService().showNotification(
      id: 999,
      title: 'Point sur vos dépenses',
      body: 'Ça fait 2 semaines ! Vérifiez vos dépenses et ajustez votre budget.',
    );

    await prefs.setString(_lastReminderKey, DateTime.now().toIso8601String());
  }

  /// Réinitialiser le dernier rappel (pour tests)
  Future<void> resetLastReminder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastReminderKey);
  }

  /// Obtenir le jour de la semaine en français
  String getDayName(int day) {
    const days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    return days[day];
  }

  /// Initialiser les rappels (à appeler au démarrage de l'app)
  Future<void> initialize() async {
    await sendReminderIfNeeded();
  }
}
