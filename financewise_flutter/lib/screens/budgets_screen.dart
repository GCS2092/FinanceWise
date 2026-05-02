import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/onboarding_tooltip.dart';
import '../theme.dart';
import '../widgets/skeleton_loader.dart';
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
    final result = await _api.delete('/budgets/$id');

    if (result is Map && result['message'] != null && (result['_conflict'] == true || result['_rate_limited'] == true)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']), backgroundColor: AppTheme.error),
        );
      }
      return;
    }
    
    // Notification de suppression
    await NotificationService().showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Budget supprimé',
      body: 'Le budget a été supprimé avec succès',
    );
    
    _load();
  }

  String _fmt(dynamic v) => AppTheme.formatCurrency(v);

  // Icône selon catégorie
  IconData _categoryIcon(String? name) {
    final n = name?.toLowerCase() ?? '';
    if (n.contains('aliment') || n.contains('food') || n.contains('nourriture')) return Icons.restaurant;
    if (n.contains('transport') || n.contains('voiture') || n.contains('car')) return Icons.directions_car;
    if (n.contains('logement') || n.contains('maison') || n.contains('house')) return Icons.home;
    if (n.contains('santé') || n.contains('health') || n.contains('medical')) return Icons.medical_services;
    if (n.contains('éducation') || n.contains('school') || n.contains('études')) return Icons.school;
    if (n.contains('shopping') || n.contains('achats') || n.contains('magasin')) return Icons.shopping_bag;
    if (n.contains('loisir') || n.contains('fun') || n.contains('divertissement')) return Icons.movie;
    if (n.contains('facture') || n.contains('utilities') || n.contains('eau') || n.contains('électricité')) return Icons.receipt_long;
    return Icons.category;
  }

  double get _totalBudget {
    double total = 0;
    for (final b in _budgets) {
      total += double.tryParse((b['amount'] ?? 0).toString()) ?? 0;
    }
    return total;
  }

  void _showBudgetDetail(Map<dynamic, dynamic> b) {
    final pct = double.tryParse((b['percentage'] ?? 0).toString()) ?? 0;
    final spent = double.tryParse((b['spent'] ?? 0).toString()) ?? 0;
    final amount = double.tryParse((b['amount'] ?? 0).toString()) ?? 0;
    final remaining = amount - spent;
    final catName = b['category']?['name'] ?? 'Budget';
    final color = pct >= 100 ? AppTheme.error : (pct >= 80 ? Colors.orange : AppTheme.primary);
    final icon = _categoryIcon(catName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
            const Gap(24),
            // Progress circulaire
            SizedBox(
              width: 120, height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: (pct / 100).clamp(0, 1),
                    strokeWidth: 8,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                      Text('dépensé', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _detailRow(Icons.category_outlined, 'Catégorie', catName),
            _detailRow(Icons.trending_up, 'Dépensé', _fmt(spent)),
            _detailRow(Icons.account_balance_wallet, 'Budget', _fmt(amount)),
            _detailRow(
              Icons.trending_down,
              'Reste',
              _fmt(remaining),
              valueColor: remaining >= 0 ? AppTheme.primary : AppTheme.error,
            ),
            const Gap(24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => BudgetFormScreen(budget: Map<String, dynamic>.from(b)))).then((_) => _load());
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Modifier'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _delete(b['id']);
                    },
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Supprimer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, {Color? valueColor}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: cs.onSurfaceVariant),
          ),
          const Gap(12),
          Text(label, style: GoogleFonts.inter(color: cs.onSurfaceVariant, fontSize: 13)),
          const Spacer(),
          Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: valueColor)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Budgets'),
            if (!_loading && _budgets.isNotEmpty)
              Text(
                '${_budgets.length} budget${_budgets.length > 1 ? 's' : ''} • ${_fmt(_totalBudget)} total',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.normal),
              ),
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
        screenName: 'budgets',
        title: 'Vos Budgets',
        description: 'Surveillez et gérez vos budgets par catégorie pour contrôler vos dépenses.',
        additionalTips: [
          TooltipItem(
            icon: Icons.pie_chart,
            title: 'Progression',
            description: 'Vert = OK, Orange = Attention (80%), Rouge = Dépassé (100%)',
          ),
          TooltipItem(
            icon: Icons.add,
            title: 'Créer un budget',
            description: 'Définissez un budget par catégorie et un montant mensuel',
          ),
          TooltipItem(
            icon: Icons.swipe,
            title: 'Détails',
            description: 'Tapez sur un budget pour voir les détails',
          ),
        ],
        child: _loading
            ? const ListSkeleton(itemCount: 3)
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
                          const SizedBox(height: 24),
                          Center(
                            child: FilledButton.icon(
                              onPressed: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetFormScreen()));
                                _load();
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Créer un budget'),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _budgets.length,
                        itemBuilder: (_, i) {
                          final b = _budgets[i];
                          final pct = double.tryParse((b['percentage'] ?? 0).toString()) ?? 0;
                          final spent = double.tryParse((b['spent'] ?? 0).toString()) ?? 0;
                          final amount = double.tryParse((b['amount'] ?? 0).toString()) ?? 0;
                          final remaining = amount - spent;
                          final catName = b['category']?['name'] ?? 'Budget';
                          final color = pct >= 100 ? AppTheme.error : (pct >= 80 ? Colors.orange : AppTheme.primary);
                          final icon = _categoryIcon(catName);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Dismissible(
                              key: Key(b['id'].toString()),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: AppTheme.error,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
                              ),
                              confirmDismiss: (_) async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Supprimer ?'),
                                    content: const Text('Ce budget sera supprimé.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                                      TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: AppTheme.error), child: const Text('Supprimer')),
                                    ],
                                  ),
                                );
                                if (confirm == true) await _delete(b['id']);
                                return false;
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: AppTheme.softShadow,
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () => _showBudgetDetail(b),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        // Progress circulaire gauche
                                        SizedBox(
                                          width: 56, height: 56,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              CircularProgressIndicator(
                                                value: (pct / 100).clamp(0, 1),
                                                strokeWidth: 6,
                                                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                valueColor: AlwaysStoppedAnimation<Color>(color),
                                              ),
                                              Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        // Info centrale
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(icon, size: 16, color: color),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    catName,
                                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Wrap(
                                                spacing: 8,
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                children: [
                                                  Text(_fmt(spent), style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
                                                  const Text(' / ', style: TextStyle(fontSize: 12)),
                                                  Text(_fmt(amount), style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: remaining >= 0 ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.error.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      remaining >= 0 ? '+${_fmt(remaining)}' : _fmt(remaining),
                                                      style: TextStyle(fontSize: 10, color: remaining >= 0 ? AppTheme.primary : AppTheme.error, fontWeight: FontWeight.w600),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outlineVariant, size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                    ),
            ),
        ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetFormScreen()));
          _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Budget'),
      ),
    );
  }
}
