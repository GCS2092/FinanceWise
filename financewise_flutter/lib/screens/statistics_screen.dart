import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/skeleton_loader.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _categoryStats = [];
  bool _loading = true;
  int _selectedPeriod = 0; // 0: Ce mois, 1: 3 mois, 2: 6 mois

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    
    try {
      final stats = await _api.get('/dashboard');
      final categories = await _api.get('/transactions/categories/stats');
      
      if (mounted) {
        setState(() {
          _stats = stats as Map<String, dynamic>?;
          _categoryStats = (categories as List?)?.cast<Map<String, dynamic>>() ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _loading
          ? const ListSkeleton(itemCount: 6)
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildPeriodSelector(),
                  const Gap(16),
                  _buildBalanceCard(),
                  const Gap(16),
                  _buildIncomeExpenseChart(),
                  const Gap(16),
                  _buildCategoryBreakdown(),
                  const Gap(16),
                  _buildTrendCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    final periods = ['Ce mois', '3 mois', '6 mois'];
    return SegmentedButton<int>(
      segments: periods.asMap().entries.map((entry) {
        return ButtonSegment(
          value: entry.key,
          label: Text(entry.value),
        );
      }).toList(),
      selected: {_selectedPeriod},
      onSelectionChanged: (Set<int> newSelection) {
        setState(() => _selectedPeriod = newSelection.first);
        _loadData();
      },
    );
  }

  Widget _buildBalanceCard() {
    final balance = _stats?['balance'] ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Solde actuel',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(8),
            Text(
              AppTheme.formatCurrency(balance),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: balance >= 0 ? AppTheme.primary : AppTheme.error,
              ),
            ).animate().fadeIn().slideX(begin: -0.1),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeExpenseChart() {
    final income = _stats?['monthly_income'] ?? 0;
    final expense = _stats?['monthly_expense'] ?? 0;
    final total = income + expense;
    
    if (total == 0) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revenus vs Dépenses',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(20),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: income.toDouble(),
                      color: AppTheme.primary,
                      title: '${AppTheme.formatCurrency(income)}',
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: expense.toDouble(),
                      color: AppTheme.error,
                      title: '${AppTheme.formatCurrency(expense)}',
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const Gap(16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem(AppTheme.primary, 'Revenus', income),
                _buildLegendItem(AppTheme.error, 'Dépenses', expense),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildLegendItem(Color color, String label, num value) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const Gap(8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              AppTheme.formatCurrency(value),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryBreakdown() {
    if (_categoryStats.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.pie_chart_outline,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const Gap(16),
              Text(
                'Aucune donnée disponible',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Gap(8),
              Text(
                'Commence par ajouter des transactions',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dépenses par catégorie',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _categoryStats.isEmpty
                      ? 100
                      : _categoryStats
                          .map((e) => e['amount'] as num)
                          .reduce((a, b) => a > b ? a : b)
                          .toDouble() *
                          1.2,
                  barGroups: _categoryStats.take(5).map((cat) {
                    return BarChartGroupData(
                      x: _categoryStats.indexOf(cat),
                      barRods: [
                        BarChartRodData(
                          toY: (cat['amount'] as num).toDouble(),
                          color: AppTheme.primary,
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= _categoryStats.length) {
                            return const SizedBox.shrink();
                          }
                          final category = _categoryStats[value.toInt()];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _shortenCategory(category['category'] ?? ''),
                              style: const TextStyle(fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                        reservedSize: 60,
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const Gap(16),
            ...(_categoryStats.take(5).map((cat) => _buildCategoryItem(cat))),
            if (_categoryStats.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: Text(
                    '+ ${_categoryStats.length - 5} autres catégories',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  String _shortenCategory(String category) {
    if (category.length <= 8) return category;
    return '${category.substring(0, 6)}...';
  }

  Widget _buildCategoryItem(Map<String, dynamic> category) {
    final amount = category['amount'] as num;
    final percentage = category['percentage'] as num? ?? 0;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category['category'] ?? '',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Gap(4),
                LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                  minHeight: 4,
                ),
              ],
            ),
          ),
          const Gap(12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppTheme.formatCurrency(amount),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard() {
    final savings = (_stats?['monthly_income'] as num? ?? 0) - (_stats?['monthly_expense'] as num? ?? 0);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Épargne du mois',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(16),
            Row(
              children: [
                Icon(
                  savings >= 0 ? Icons.trending_up : Icons.trending_down,
                  color: savings >= 0 ? AppTheme.primary : AppTheme.error,
                  size: 32,
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTheme.formatCurrency(savings.abs()),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: savings >= 0 ? AppTheme.primary : AppTheme.error,
                        ),
                      ),
                      Text(
                        savings >= 0 ? 'Épargne positive' : 'Dépassement',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }
}
