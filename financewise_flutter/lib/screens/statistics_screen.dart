import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  Map<String, dynamic>? _data;
  List<dynamic> _transactions = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dashboardResult = await _api.get('/dashboard');
      final transactionsResult = await _api.get('/transactions');
      
      final tData = transactionsResult is Map ? (transactionsResult['data'] ?? transactionsResult) : transactionsResult;
      
      setState(() {
        _data = dashboardResult is Map<String, dynamic> ? dashboardResult : {};
        _transactions = tData is List ? tData : [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Map<String, double> _getCategorySpending() {
    final Map<String, double> categorySpending = {};
    for (final t in _transactions) {
      if (t['type'] == 'expense' && t['category'] is Map) {
        final name = t['category']['name'] ?? 'Autre';
        final amount = (t['amount'] ?? 0).toDouble();
        categorySpending[name] = (categorySpending[name] ?? 0) + amount;
      }
    }
    return categorySpending;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppTheme.error)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Résumé ──
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Résumé', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _StatItem(
                                      label: 'Balance',
                                      value: _formatAmount(_data?['balance']),
                                      color: AppTheme.secondary,
                                    ),
                                    _StatItem(
                                      label: 'Revenus',
                                      value: _formatAmount(_data?['monthly_income']),
                                      color: AppTheme.primary,
                                    ),
                                    _StatItem(
                                      label: 'Dépenses',
                                      value: _formatAmount(_data?['monthly_expense']),
                                      color: AppTheme.error,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Dépenses par catégorie ──
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Dépenses par catégorie', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 250,
                                  child: _buildCategoryChart(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Graphique à barres (dépenses par catégorie) ──
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Dépenses par catégorie (barres)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 250,
                                  child: _buildBarChart(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Top dépenses ──
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Top dépenses', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 16),
                                ...(_transactions
                                    .where((t) => t['type'] == 'expense')
                                    .toList()
                                  ..sort((a, b) => ((b['amount'] ?? 0) as num).compareTo((a['amount'] ?? 0) as num))
                                ).take(5).map((t) => ListTile(
                                      dense: true,
                                      title: Text(t['description'] ?? ''),
                                      subtitle: Text(t['category'] is Map ? t['category']['name'] : ''),
                                      trailing: Text(_formatAmount(t['amount']), style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
                                    )),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildCategoryChart() {
    final categorySpending = _getCategorySpending();
    if (categorySpending.isEmpty) {
      return const Center(child: Text('Aucune donnée de dépense'));
    }

    final colors = [
      AppTheme.primary, AppTheme.error, Colors.green, Colors.orange, AppTheme.tertiary,
      Colors.pink, Colors.teal, Colors.amber, Colors.cyan, Colors.indigo,
    ];

    final total = categorySpending.values.reduce((a, b) => a + b);
    final entries = categorySpending.entries.toList();
    
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: entries.asMap().entries.map((entry) {
                final index = entry.key;
                final category = entry.value;
                final value = category.value;
                final percentage = (value / total * 100).toStringAsFixed(1);
                return PieChartSectionData(
                  value: value,
                  title: '$percentage%',
                  color: colors[index % colors.length],
                  radius: 55,
                  titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: entries.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors[index % colors.length],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text(category.key, style: Theme.of(context).textTheme.bodySmall),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBarChart() {
    final categorySpending = _getCategorySpending();
    if (categorySpending.isEmpty) {
      return const Center(child: Text('Aucune donnée de dépense'));
    }

    final colors = [
      AppTheme.primary, AppTheme.error, Colors.green, Colors.orange, AppTheme.tertiary,
      Colors.pink, Colors.teal, Colors.amber, Colors.cyan, Colors.indigo,
    ];

    final entries = categorySpending.entries.toList();
    final maxValue = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue * 1.2,
        barGroups: entries.asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: category.value,
                color: colors[index % colors.length],
                width: 20,
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
                if (value.toInt() >= entries.length) return const SizedBox.shrink();
                final categoryName = entries[value.toInt()].key;
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    categoryName.length > 8 ? '${categoryName.substring(0, 8)}...' : categoryName,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: false),
      ),
    );
  }

  String _formatAmount(dynamic value) {
    final amount = (value ?? 0).toDouble();
    return NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF ', decimalDigits: 0).format(amount);
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
