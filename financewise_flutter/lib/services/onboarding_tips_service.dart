import 'package:shared_preferences/shared_preferences.dart';

class OnboardingTipsService {
  static const String _prefix = 'onboarding_tip_shown_';
  
  static Future<bool> hasSeenTip(String screenName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefix$screenName') ?? false;
  }
  
  static Future<void> markTipAsSeen(String screenName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$screenName', true);
  }
  
  static Future<void> resetTip(String screenName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$screenName');
  }
  
  static Future<void> resetAllTips() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_prefix)) {
        await prefs.remove(key);
      }
    }
  }
}
