import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/sms_listener_service.dart';
import '../services/pending_sms_service.dart';
import '../widgets/onboarding_tooltip.dart';
import '../theme.dart';
import '../widgets/skeleton_loader.dart';
import 'transaction_form_screen.dart';
import 'transactions_screen.dart';
import 'budgets_screen.dart';
import 'sms_parser_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService();
  bool _loading = true;
  bool _balanceHidden = false;
  Map<String, dynamic>? _data;
  String? _error;
  final Set<int> _dismissedAlerts = {};
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

  String _formatAmount(dynamic value) => AppTheme.formatCurrency(value);

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
        body: const DashboardSkeleton(),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bonjour 👋', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.normal)),
            const SizedBox(height: 2),
            const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
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
              // ── Carte bancaire (héro) ──
              _buildBankCard(balance, income, expense),
              const SizedBox(height: 16),

              // ── Actions rapides (compactes) ──
              Row(
                children: [
                  _buildQuickChip(Icons.add, 'Transaction', () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionFormScreen()));
                    _loadDashboard();
                  }),
                  const SizedBox(width: 8),
                  _buildQuickChip(Icons.sms_outlined, 'Importer SMS', () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const SmsParserScreen()));
                    _loadDashboard();
                  }),
                ],
              ),
              const SizedBox(height: 20),

              // ── Alertes ──
              ...alerts.asMap().entries
                  .where((e) => !_dismissedAlerts.contains(e.key))
                  .take(3)
                  .map((e) => _buildAlert(e.value, e.key)),
              if (alerts.where((a) => !_dismissedAlerts.contains(alerts.indexOf(a))).isNotEmpty)
                const SizedBox(height: 12),

              // ── Objectif de revenu (compact) ──
              if (incomeTarget > 0) ...[
                _buildIncomeGoal(income, incomeTarget, incomeProgress),
                const SizedBox(height: 16),
              ],

              // ── Budgets actifs (max 2) ──
              _buildSectionHeader('Budgets actifs', onSeeAll: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetsScreen()));
              }),
              const SizedBox(height: 8),
              _buildActiveBudgets(),
              const SizedBox(height: 20),

              // ── Transactions récentes (max 3) ──
              _buildSectionHeader('Transactions récentes', onSeeAll: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionsScreen()));
              }),
              const SizedBox(height: 8),
              _buildRecentTransactions(),
              const SizedBox(height: 80),
            ],
        ),
      ),
      ),
      ),
    );
  }

  // ── Carte bancaire style ──
  Widget _buildBankCard(dynamic balance, dynamic income, dynamic expense) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.strongShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                  const Gap(10),
                  Text('FinanceWise', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.8)),
                ],
              ),
              GestureDetector(
                onTap: () => setState(() => _balanceHidden = !_balanceHidden),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(_balanceHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white70, size: 18),
                ),
              ),
            ],
          ),
          const Gap(24),
          // Solde
          Text('Solde total', style: GoogleFonts.inter(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w400)),
          const Gap(6),
          Text(
            _balanceHidden ? '••••••••' : _formatAmount(balance),
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: 0.3),
          ),
          const Gap(24),
          // Revenus / Dépenses
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: const Color(0xFF69F0AE).withValues(alpha: 0.25), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.trending_up_rounded, color: Color(0xFF69F0AE), size: 16),
                          ),
                          const Gap(10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Revenus', style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                                const Gap(2),
                                Text(
                                  _balanceHidden ? '••••' : _formatAmount(income),
                                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 36, margin: const EdgeInsets.symmetric(horizontal: 4), color: Colors.white.withValues(alpha: 0.15)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: const Color(0xFFFF8A80).withValues(alpha: 0.25), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.trending_down_rounded, color: Color(0xFFFF8A80), size: 16),
                            ),
                            const Gap(10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Dépenses', style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                                  const Gap(2),
                                  Text(
                                    _balanceHidden ? '••••' : _formatAmount(expense),
                                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.1, end: 0, duration: 500.ms, curve: Curves.easeOut);
  }

  // ── Chip action rapide ──
  Widget _buildQuickChip(IconData icon, String label, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.softShadow,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: cs.primary),
                  ),
                  const Gap(10),
                  Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Objectif revenu compact ──
  Widget _buildIncomeGoal(dynamic income, dynamic target, dynamic progress) {
    final pct = (progress is num ? progress : 0).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: pct >= 100 ? AppTheme.primaryContainer : Theme.of(context).colorScheme.secondaryContainer,
              child: Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: pct >= 100 ? AppTheme.onPrimaryContainer : Theme.of(context).colorScheme.onSecondaryContainer)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Objectif de revenu', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (pct / 100).clamp(0, 1).toDouble(),
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(pct >= 100 ? AppTheme.primary : Theme.of(context).colorScheme.secondary),
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text('${_formatAmount(income)} sur ${_formatAmount(target)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: cs.onSurface)),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Voir tout', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary)),
                  const Gap(4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: cs.primary),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAlert(dynamic alert, int index) {
    final type = alert['type'] ?? 'warning';
    final color = type == 'danger' ? AppTheme.error : Colors.orange;
    final iconData = type == 'danger' ? Icons.error : Icons.warning_amber_rounded;
    return Card(
      color: color.withValues(alpha: 0.08),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(iconData, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                alert['message'] ?? '',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w500),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _dismissedAlerts.add(index)),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16, color: color.withValues(alpha: 0.6)),
              ),
            ),
          ],
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
      children: budgetList.take(2).map((b) {
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
                if (percentage >= 80 && percentage < 100) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Attention : ${percentage.toStringAsFixed(0)}% du budget $categoryName utilisé. Ralentissez vos dépenses.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ],
                if (percentage >= 100) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.warning_amber, size: 14, color: AppTheme.error),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Budget $categoryName dépassé de ${_formatAmount(spent - amount)}.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.error, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ],
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
              const SizedBox(height: 4),
              Text('Ajoutez-en une avec le bouton ci-dessus', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Column(
        children: transactions.take(3).toList().asMap().entries.map((entry) {
          final i = entry.key;
          final t = entry.value;
          if (t is! Map) return const SizedBox.shrink();
          final isIncome = t['type'] == 'income';
          final category = t['category'];
          final catName = category is Map ? (category['name']?.toString() ?? '') : '';
          final date = t['transaction_date']?.toString() ?? '';
          final shortDate = date.length >= 10 ? '${date.substring(8, 10)}/${date.substring(5, 7)}' : '';
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: isIncome ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(isIncome ? Icons.south_west : Icons.north_east, color: isIncome ? AppTheme.primary : AppTheme.error, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t['description']?.toString() ?? 'Transaction',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$catName${catName.isNotEmpty && shortDate.isNotEmpty ? '  •  ' : ''}$shortDate',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isIncome ? '+' : '-'}${_formatAmount(t['amount'])}',
                      style: TextStyle(color: isIncome ? AppTheme.primary : AppTheme.error, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (i < 2 && i < transactions.length - 1)
                Divider(height: 1, indent: 64, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ],
          );
        }).toList(),
      ),
    );
  }
}
