import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class OfflineCacheService {
  static final OfflineCacheService _instance = OfflineCacheService._internal();
  factory OfflineCacheService() => _instance;
  OfflineCacheService._internal();

  Future<SharedPreferences> get prefs async {
    return SharedPreferences.getInstance();
  }

  // Cache transactions
  Future<void> cacheTransactions(List<dynamic> transactions) async {
    final p = await prefs;
    await p.setString('cached_transactions', jsonEncode(transactions));
    await p.setString('transactions_cached_at', DateTime.now().toIso8601String());
  }

  Future<List<dynamic>> getCachedTransactions() async {
    final p = await prefs;
    final cached = p.getString('cached_transactions');
    if (cached != null) {
      return jsonDecode(cached);
    }
    return [];
  }

  // Cache balance
  Future<void> cacheBalance(Map<String, dynamic> balance) async {
    final p = await prefs;
    await p.setString('cached_balance', jsonEncode(balance));
    await p.setString('balance_cached_at', DateTime.now().toIso8601String());
  }

  Future<Map<String, dynamic>?> getCachedBalance() async {
    final p = await prefs;
    final cached = p.getString('cached_balance');
    if (cached != null) {
      return jsonDecode(cached);
    }
    return null;
  }

  // Cache budgets
  Future<void> cacheBudgets(List<dynamic> budgets) async {
    final p = await prefs;
    await p.setString('cached_budgets', jsonEncode(budgets));
    await p.setString('budgets_cached_at', DateTime.now().toIso8601String());
  }

  Future<List<dynamic>> getCachedBudgets() async {
    final p = await prefs;
    final cached = p.getString('cached_budgets');
    if (cached != null) {
      return jsonDecode(cached);
    }
    return [];
  }

  // Cache financial goals
  Future<void> cacheFinancialGoals(List<dynamic> goals) async {
    final p = await prefs;
    await p.setString('cached_goals', jsonEncode(goals));
    await p.setString('goals_cached_at', DateTime.now().toIso8601String());
  }

  Future<List<dynamic>> getCachedFinancialGoals() async {
    final p = await prefs;
    final cached = p.getString('cached_goals');
    if (cached != null) {
      return jsonDecode(cached);
    }
    return [];
  }

  // Cache dashboard
  Future<void> cacheDashboard(Map<String, dynamic> dashboard) async {
    final p = await prefs;
    await p.setString('cached_dashboard', jsonEncode(dashboard));
    await p.setString('dashboard_cached_at', DateTime.now().toIso8601String());
  }

  Future<Map<String, dynamic>?> getCachedDashboard() async {
    final p = await prefs;
    final cached = p.getString('cached_dashboard');
    if (cached != null) {
      return jsonDecode(cached);
    }
    return null;
  }

  // Vérifier si le cache est valide (moins de 24h)
  Future<bool> isCacheValid(String cacheKey) async {
    final p = await prefs;
    final cachedAt = p.getString('${cacheKey}_cached_at');
    if (cachedAt == null) return false;
    
    final cachedDate = DateTime.parse(cachedAt);
    final now = DateTime.now();
    return now.difference(cachedDate).inHours < 24;
  }

  // Clear all cache
  Future<void> clearCache() async {
    final p = await prefs;
    await p.remove('cached_transactions');
    await p.remove('transactions_cached_at');
    await p.remove('cached_balance');
    await p.remove('balance_cached_at');
    await p.remove('cached_budgets');
    await p.remove('budgets_cached_at');
    await p.remove('cached_goals');
    await p.remove('goals_cached_at');
    await p.remove('cached_dashboard');
    await p.remove('dashboard_cached_at');
  }
}
