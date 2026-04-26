import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/sms_listener_service.dart';
import '../services/pending_sms_service.dart';
import '../widgets/onboarding_tooltip.dart';
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
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadDashboard, child: const Text('Réessayer')),
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
                      color: Colors.blue,
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
                      color: Colors.purple,
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
              color: balance >= 0 ? Colors.green : Colors.red,
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
                    color: Colors.green,
                    icon: Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCard(
                    title: 'Dépenses (mois)',
                    value: _formatAmount(expense),
                    color: Colors.red,
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Objectif de revenu',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${incomeProgress.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: incomeProgress >= 100 ? Colors.green : Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: (incomeProgress / 100).clamp(0, 1),
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          incomeProgress >= 100 ? Colors.green : Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Réalisé: ${_formatAmount(income)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'Objectif: ${_formatAmount(incomeTarget)}',
                            style: const TextStyle(fontSize: 12),
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
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Répartition du mois', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(
                              value: income.toDouble(),
                              title: '${((income / (income + expense)) * 100).toStringAsFixed(0)}%',
                              color: Colors.green,
                              radius: 50,
                              titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            PieChartSectionData(
                              value: expense.toDouble(),
                              title: '${((expense / (income + expense)) * 100).toStringAsFixed(0)}%',
                              color: Colors.red,
                              radius: 50,
                              titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 12, height: 12, color: Colors.green),
                        const SizedBox(width: 4),
                        const Text('Revenus'),
                        const SizedBox(width: 16),
                        Container(width: 12, height: 12, color: Colors.red),
                        const SizedBox(width: 4),
                        const Text('Dépenses'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Budgets actifs ──
            Text('Budgets actifs', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildActiveBudgets(),
            const SizedBox(height: 24),

            // ── Alertes ──
            if (alerts.isNotEmpty) ...[
              Text('Alertes', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...alerts.map((a) => _buildAlert(a)),
              const SizedBox(height: 24),
            ],

            // ── Transactions récentes ──
            Text('Transactions récentes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
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
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Icon(icon, color: color, size: 20),
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
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
                  color: color.withOpacity(0.1),
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
    final color = type == 'danger' ? Colors.red : Colors.orange;
    return Card(
      color: color.withValues(alpha: 0.1),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.warning, color: color),
        title: Text(alert['message'] ?? '', style: TextStyle(color: color)),
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
      return const Text('Aucun budget actif', style: TextStyle(color: Colors.grey));
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
        
        Color progressColor = Colors.green;
        if (percentage >= 90) progressColor = Colors.red;
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
                    Text(categoryName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${percentage.toStringAsFixed(0)}%', style: TextStyle(color: progressColor, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Dépensé: ${_formatAmount(spent)}', style: const TextStyle(fontSize: 12)),
                    Text('Reste: ${_formatAmount(remaining)}', style: const TextStyle(fontSize: 12)),
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
      return const Text('Aucune transaction', style: TextStyle(color: Colors.grey));
    }
    return Column(
      children: transactions.take(5).map((t) {
        if (t is! Map) return const SizedBox.shrink();
        final isIncome = t['type'] == 'income';
        final category = t['category'];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isIncome ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
            child: Icon(isIncome ? Icons.arrow_upward : Icons.arrow_downward, color: isIncome ? Colors.green : Colors.red),
          ),
          title: Text(t['description']?.toString() ?? 'Transaction'),
          subtitle: Text(category is Map ? (category['name']?.toString() ?? '') : ''),
          trailing: Text(
            '${isIncome ? '+' : '-'}${_formatAmount(t['amount']).replaceAll('XOF ', '')}',
            style: TextStyle(color: isIncome ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
          ),
        );
      }).toList(),
    );
  }
}
