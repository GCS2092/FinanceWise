import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/onboarding_tooltip.dart';
import '../theme.dart';
import 'budget_form_screen.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  final _api = ApiService();
  List<dynamic> _budgets = [];
  bool _loading = true;
  String? _error;
  final GlobalKey<OnboardingTooltipState> _tooltipKey = GlobalKey<OnboardingTooltipState>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _api.get('/budgets');
    if (mounted) {
      setState(() {
        _loading = false;
        if (result is Map && result.containsKey('data')) {
          _budgets = result['data'] as List;
        } else if (result is List) {
          _budgets = result;
        } else {
          _error = result?['message'] ?? 'Erreur';
        }
      });
    }
  }

  Future<void> _delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: const Text('Ce budget sera supprimé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _api.delete('/budgets/$id');
    
    // Notification de suppression
    await NotificationService().showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Budget supprimé',
      body: 'Le budget a été supprimé avec succès',
    );
    
    _load();
  }

  String _fmt(dynamic v) {
    final n = (v ?? 0).toDouble();
    return NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF ', decimalDigits: 0).format(n);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
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
        screenName: 'budgets',
        title: 'Vos Budgets',
        description: 'Surveillez et gérez vos budgets par catégorie pour contrôler vos dépenses.',
        additionalTips: [
          TooltipItem(
            icon: Icons.pie_chart,
            title: 'Barre de progression',
            description: 'Vert = OK, Orange = Attention (80%), Rouge = Dépassé (100%)',
          ),
          TooltipItem(
            icon: Icons.add,
            title: 'Créer un budget',
            description: 'Définissez un budget par catégorie et un montant mensuel',
          ),
          TooltipItem(
            icon: Icons.edit,
            title: 'Modifier',
            description: 'Tap pour modifier le montant ou la période',
          ),
        ],
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _budgets.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 80),
                          Icon(Icons.pie_chart_outline, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                          const SizedBox(height: 16),
                          Center(child: Text('Aucun budget', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500))),
                          const SizedBox(height: 8),
                          Center(child: Text('Créez un budget pour contrôler vos dépenses', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _budgets.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final b = _budgets[i];
                          final pct = (b['percentage'] ?? 0).toDouble();
                          final color = pct >= 100 ? AppTheme.error : (pct >= 80 ? Colors.orange : AppTheme.primary);
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          b['category']?['name'] ?? 'Budget',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${_fmt(b['spent']).replaceAll('XOF ', '')} / ${_fmt(b['amount']).replaceAll('XOF ', '')}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: (pct / 100).clamp(0, 1),
                                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      valueColor: AlwaysStoppedAnimation<Color>(color),
                                      minHeight: 8,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${pct.toStringAsFixed(0)}% dépensé',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      Text(
                                        'Reste: ${_fmt(b['amount'] - b['spent'])}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () async {
                                          await Navigator.push(context, MaterialPageRoute(builder: (_) => BudgetFormScreen(budget: b)));
                                          _load();
                                        },
                                        child: const Text('Modifier'),
                                      ),
                                      TextButton(
                                        onPressed: () => _delete(b['id']),
                                        child: Text(
                                          'Supprimer',
                                          style: TextStyle(color: AppTheme.error),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                    ),
            ),
        ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetFormScreen()));
          _load();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
