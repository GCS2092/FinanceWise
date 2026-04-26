import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/sms_listener_service.dart';
import '../services/pending_sms_service.dart';
import '../widgets/onboarding_tooltip.dart';
import '../theme.dart';
import 'transaction_form_screen.dart';
import 'sms_parser_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService();
  bool _loading = true;
  Map<String, dynamic>? _data;
  String? _error;
  final GlobalKey<OnboardingTooltipState> _tooltipKey = GlobalKey<OnboardingTooltipState>();
  SmsListenerService? _smsListener;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _initSmsListener();
    _checkPendingSms();
  }

  void _initSmsListener() {
    _smsListener = SmsListenerService.getInstance(
      context: context,
      onTransactionAdded: _loadDashboard,
    );
    _smsListener?.startListening();
  }

  Future<void> _checkPendingSms() async {
    // Vérifier s'il y a un SMS en attente (quand l'app s'ouvre depuis une notification)
    await PendingSmsService.showPendingSmsDialog(context);
  }

  @override
  void dispose() {
    _smsListener?.stopListening();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _api.get('/dashboard');

    if (result is Map<String, dynamic>) {
      setState(() {
        _data = result;
        _loading = false;
      });

      // Afficher des notifications pour les alertes budget
      final alerts = (result['alerts'] as List<dynamic>?) ?? [];
      for (final alert in alerts) {
        await NotificationService().showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'Alerte Budget',
          body: alert['message'] ?? 'Alerte budget',
        );
      }
    } else if (result is Map && result.containsKey('message')) {
      setState(() {
        _error = result['message'];
        _loading = false;
      });
    } else {
      setState(() {
        _error = 'Erreur lors du chargement';
        _loading = false;
      });
    }
  }

  String _formatAmount(dynamic value) {
    final amount = (value ?? 0).toDouble();
    return NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF ', decimalDigits: 0).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () => _tooltipKey.currentState?.showTooltip(),
              tooltip: 'Aide',
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () => _tooltipKey.currentState?.showTooltip(),
              tooltip: 'Aide',
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppTheme.error)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadDashboard,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final balance = _data?['balance'] ?? 0;
    final income = _data?['monthly_income'] ?? 0;
    final expense = _data?['monthly_expense'] ?? 0;
    final incomeTarget = _data?['monthly_income_target'] ?? 0;
    final incomeProgress = _data?['income_progress'] ?? 0;
    final alerts = (_data?['alerts'] as List<dynamic>?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _tooltipKey.currentState?.showTooltip(),
            tooltip: 'Aide',
          ),
        ],
      ),
      body: OnboardingTooltip(
        key: _tooltipKey,
        screenName: 'dashboard',
        title: 'Bienvenue sur votre Dashboard',
        description: 'C\'est votre vue d\'ensemble de vos finances. Ici vous pouvez voir votre solde, vos revenus et dépenses du mois.',
        additionalTips: [
          TooltipItem(
            icon: Icons.account_balance_wallet,
            title: 'Solde Total',
            description: 'La somme de tous vos portefeuilles (Wave, Orange Money, Banque, Espèces)',
          ),
          TooltipItem(
            icon: Icons.trending_up,
            title: 'Revenus',
            description: 'Total des revenus enregistrés ce mois',
          ),
          TooltipItem(
            icon: Icons.trending_down,
            title: 'Dépenses',
            description: 'Total des dépenses enregistrées ce mois',
          ),
          TooltipItem(
            icon: Icons.add,
            title: 'Ajouter Transaction',
            description: 'Cliquez pour ajouter une nouvelle dépense ou revenu',
          ),
          TooltipItem(
            icon: Icons.sms,
            title: 'Parser SMS',
            description: 'Collez vos SMS Wave/Orange Money pour les ajouter automatiquement',
          ),
        ],
      child: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Actions rapides ──
              Row(
                children: [
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.add,
                      label: 'Transaction',
                      color: Theme.of(context).colorScheme.primary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TransactionFormScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.sms,
                      label: 'Parser SMS',
                      color: Theme.of(context).colorScheme.tertiary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SmsParserScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            // ── Solde ──
            _buildCard(
              title: 'Solde total',
              value: _formatAmount(balance),
              color: balance >= 0 ? AppTheme.primary : AppTheme.error,
              icon: Icons.account_balance_wallet,
            ),
            const SizedBox(height: 16),

            // ── Revenus / Dépenses ──
            Row(
              children: [
                Expanded(
                  child: _buildCard(
                    title: 'Revenus (mois)',
                    value: _formatAmount(income),
                    color: AppTheme.primary,
                    icon: Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCard(
                    title: 'Dépenses (mois)',
                    value: _formatAmount(expense),
                    color: AppTheme.error,
                    icon: Icons.trending_down,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Objectif de revenu ──
            if (incomeTarget > 0) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Objectif de revenu',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: incomeProgress >= 100 
                                ? AppTheme.primaryContainer 
                                : Theme.of(context).colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${incomeProgress.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: incomeProgress >= 100 
                                  ? AppTheme.onPrimaryContainer 
                                  : Theme.of(context).colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (incomeProgress / 100).clamp(0, 1),
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            incomeProgress >= 100 ? AppTheme.primary : Theme.of(context).colorScheme.secondary,
                          ),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Réalisé: ${_formatAmount(income)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            'Objectif: ${_formatAmount(incomeTarget)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Graphique Revenus/Dépenses ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Répartition du mois',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(
                              value: income.toDouble(),
                              title: '${((income / (income + expense)) * 100).toStringAsFixed(0)}%',
                              color: AppTheme.primary,
                              radius: 50,
                              titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            PieChartSectionData(
                              value: expense.toDouble(),
                              title: '${((expense / (income + expense)) * 100).toStringAsFixed(0)}%',
                              color: AppTheme.error,
                              radius: 50,
                              titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLegend(AppTheme.primary, 'Revenus'),
                        const SizedBox(width: 20),
                        _buildLegend(AppTheme.error, 'Dépenses'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Budgets actifs ──
            Text(
              'Budgets actifs',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildActiveBudgets(),
            const SizedBox(height: 24),

            // ── Alertes ──
            if (alerts.isNotEmpty) ...[
              Text(
                'Alertes',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ...alerts.map((a) => _buildAlert(a)),
              const SizedBox(height: 24),
            ],

            // ── Transactions récentes ──
            Text(
              'Transactions récentes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildRecentTransactions(),
          ],
        ),
      ),
      ),
      ),
    );
  }

  Widget _buildCard({required String title, required String value, required Color color, required IconData icon}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _QuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlert(dynamic alert) {
    final type = alert['type'] ?? 'warning';
    final color = type == 'danger' ? AppTheme.error : Colors.orange;
    final icon = type == 'danger' ? Icons.error : Icons.warning_amber_rounded;
    return Card(
      color: color.withValues(alpha: 0.08),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          alert['message'] ?? '',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildActiveBudgets() {
    if (_data is! Map<String, dynamic>) return const SizedBox.shrink();
    dynamic budgets = _data?['budgets'];
    List<dynamic> budgetList = [];
    if (budgets is List) {
      budgetList = budgets;
    } else if (budgets is Map) {
      budgetList = (budgets['data'] as List<dynamic>?) ?? [];
    }
    if (budgetList.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.pie_chart_outline, size: 40, color: Theme.of(context).colorScheme.outlineVariant),
              const SizedBox(height: 8),
              Text('Aucun budget actif', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }
    return Column(
      children: budgetList.map((b) {
        if (b is! Map) return const SizedBox.shrink();
        final category = b['category'];
        final categoryName = category is Map ? (category['name']?.toString() ?? 'Sans catégorie') : 'Sans catégorie';
        final spent = (b['spent'] ?? 0).toDouble();
        final amount = (b['amount'] ?? 0).toDouble();
        final percentage = amount > 0 ? (spent / amount * 100).clamp(0, 100) : 0.0;
        final remaining = amount - spent;
        
        Color progressColor = AppTheme.primary;
        if (percentage >= 90) progressColor = AppTheme.error;
        else if (percentage >= 70) progressColor = Colors.orange;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(categoryName, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: progressColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${percentage.toStringAsFixed(0)}%', style: TextStyle(color: progressColor, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Dépensé: ${_formatAmount(spent)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    Text('Reste: ${_formatAmount(remaining)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: remaining >= 0 ? AppTheme.primary : AppTheme.error)),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentTransactions() {
    if (_data is! Map<String, dynamic>) return const SizedBox.shrink();
    dynamic recent = _data?['recent_transactions'];
    List<dynamic> transactions = [];
    if (recent is List) {
      transactions = recent;
    } else if (recent is Map) {
      transactions = (recent['data'] as List<dynamic>?) ?? [];
    }
    if (transactions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined, size: 40, color: Theme.of(context).colorScheme.outlineVariant),
              const SizedBox(height: 8),
              Text('Aucune transaction', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }
    return Column(
      children: transactions.take(5).map((t) {
        if (t is! Map) return const SizedBox.shrink();
        final isIncome = t['type'] == 'income';
        final category = t['category'];
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isIncome ? AppTheme.primary.withValues(alpha: 0.12) : AppTheme.error.withValues(alpha: 0.12),
              child: Icon(isIncome ? Icons.arrow_upward : Icons.arrow_downward, color: isIncome ? AppTheme.primary : AppTheme.error, size: 20),
            ),
            title: Text(t['description']?.toString() ?? 'Transaction', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            subtitle: Text(category is Map ? (category['name']?.toString() ?? '') : '', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            trailing: Text(
              '${isIncome ? '+' : '-'}${_formatAmount(t['amount']).replaceAll('XOF ', '')}',
              style: TextStyle(color: isIncome ? AppTheme.primary : AppTheme.error, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }).toList(),
    );
  }
}
