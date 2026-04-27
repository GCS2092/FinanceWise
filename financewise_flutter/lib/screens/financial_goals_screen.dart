import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'financial_goal_form_screen.dart';

class FinancialGoalsScreen extends StatefulWidget {
  const FinancialGoalsScreen({super.key});

  @override
  State<FinancialGoalsScreen> createState() => _FinancialGoalsScreenState();
}

class _FinancialGoalsScreenState extends State<FinancialGoalsScreen> {
  final _api = ApiService();
  List<dynamic> _goals = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _api.get('/financial-goals');
    if (mounted) {
      setState(() {
        _loading = false;
        if (result is Map && result.containsKey('data')) {
          _goals = result['data'] as List;
        } else if (result is List) {
          _goals = result;
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
        content: const Text('Cet objectif sera définitivement supprimé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirm != true) return;

    await _api.delete('/financial-goals/$id');
    _load();
  }

  String _formatAmount(dynamic value) => AppTheme.formatCurrency(value);

  // Icône selon nom d'objectif
  IconData _goalIcon(String? name) {
    final n = name?.toLowerCase() ?? '';
    if (n.contains('voiture') || n.contains('car') || n.contains('auto')) return Icons.directions_car;
    if (n.contains('maison') || n.contains('logement') || n.contains('house')) return Icons.home;
    if (n.contains('voyage') || n.contains('travel') || n.contains('vacances')) return Icons.flight;
    if (n.contains('épargne') || n.contains('saving') || n.contains('economie')) return Icons.savings;
    if (n.contains('étude') || n.contains('education') || n.contains('école')) return Icons.school;
    if (n.contains('téléphone') || n.contains('phone') || n.contains('mobile')) return Icons.smartphone;
    if (n.contains('ordinateur') || n.contains('laptop') || n.contains('pc')) return Icons.laptop;
    if (n.contains('mariage') || n.contains('wedding')) return Icons.favorite;
    if (n.contains('retraite') || n.contains('pension')) return Icons.elderly;
    return Icons.flag;
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed':
        return AppTheme.primary;
      case 'in_progress':
        return AppTheme.tertiary;
      default:
        return Colors.orange;
    }
  }

  void _showGoalDetail(Map<dynamic, dynamic> goal) {
    final name = goal['name'] ?? 'Objectif';
    final description = goal['description'];
    final currentAmount = (goal['current_amount'] ?? 0).toDouble();
    final targetAmount = (goal['target_amount'] ?? 0).toDouble();
    final remaining = targetAmount - currentAmount;
    final progress = targetAmount > 0 ? (currentAmount / targetAmount) * 100 : 0;
    final status = goal['status'] ?? '';
    final targetDate = goal['target_date'];
    final color = _getStatusColor(status);
    final icon = _goalIcon(name);

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
                    value: (progress / 100).clamp(0, 1),
                    strokeWidth: 8,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${progress.toStringAsFixed(0)}%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                      Text('atteint', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
            const Gap(20),
            _detailRow(Icons.flag_outlined, 'Objectif', name),
            if (description != null) _detailRow(Icons.description_outlined, 'Description', description),
            _detailRow(Icons.trending_up, 'Actuel', _formatAmount(currentAmount)),
            _detailRow(Icons.account_balance_wallet, 'Cible', _formatAmount(targetAmount)),
            _detailRow(
              Icons.trending_down,
              'Reste',
              _formatAmount(remaining),
              valueColor: remaining <= 0 ? AppTheme.primary : Colors.orange,
            ),
            if (targetDate != null) _detailRow(Icons.calendar_today, 'Date cible', DateFormat('dd/MM/yyyy').format(DateTime.parse(targetDate))),
            _detailRow(Icons.info_outline, 'Statut', status == 'completed' ? 'Atteint' : 'En cours', valueColor: color),
            const Gap(24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => FinancialGoalFormScreen(financialGoal: Map<String, dynamic>.from(goal)))).then((_) => _load());
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
                      _showAddAmountDialog(goal);
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Ajouter'),
                  ),
                ),
              ],
            ),
            const Gap(12),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _delete(goal['id']);
              },
              style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Supprimer'),
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
            const Text('Objectifs financiers'),
            if (!_loading && _goals.isNotEmpty)
              Text(
                '${_goals.length} objectif${_goals.length > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.normal),
              ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _error != null
                  ? ListView(
                      children: [
                        const SizedBox(height: 100),
                        const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                        const SizedBox(height: 12),
                        Center(child: Text(_error!, style: const TextStyle(color: AppTheme.error))),
                      ],
                    )
                  : _goals.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            Icon(Icons.flag_outlined, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                            const SizedBox(height: 16),
                            Center(child: Text('Aucun objectif', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500))),
                            const SizedBox(height: 8),
                            Center(child: Text('Définissez un objectif d\'\u00e9pargne avec le bouton +', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _goals.length,
                          itemBuilder: (_, i) {
                            final goal = _goals[i];
                            final name = goal['name'] ?? 'Objectif';
                            final currentAmount = (goal['current_amount'] ?? 0).toDouble();
                            final targetAmount = (goal['target_amount'] ?? 0).toDouble();
                            final remaining = targetAmount - currentAmount;
                            final progress = targetAmount > 0 ? (currentAmount / targetAmount) * 100 : 0;
                            final status = goal['status'] ?? '';
                            final color = _getStatusColor(status);
                            final icon = _goalIcon(name);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Dismissible(
                                key: Key(goal['id'].toString()),
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
                                      content: const Text('Cet objectif sera définitivement supprimé.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) await _delete(goal['id']);
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
                                    onTap: () => _showGoalDetail(goal),
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
                                                  value: (progress / 100).clamp(0, 1),
                                                  strokeWidth: 6,
                                                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                  valueColor: AlwaysStoppedAnimation<Color>(color),
                                                ),
                                                Text('${progress.toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
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
                                                      name,
                                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Wrap(
                                                  spacing: 8,
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  children: [
                                                    Text(_formatAmount(currentAmount), style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
                                                    const Text(' / ', style: TextStyle(fontSize: 12)),
                                                    Text(_formatAmount(targetAmount), style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: remaining <= 0 ? AppTheme.primary.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        remaining <= 0 ? 'Atteint!' : _formatAmount(remaining),
                                                        style: TextStyle(fontSize: 10, color: remaining <= 0 ? AppTheme.primary : Colors.orange, fontWeight: FontWeight.w600),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancialGoalFormScreen()));
          _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Objectif'),
      ),
    );
  }

  void _showAddAmountDialog(dynamic goal) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter un montant'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Montant (FCFA)',
            suffixText: 'FCFA',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                await _api.post('/financial-goals/${goal['id']}/add-amount', {
                  'amount': amount,
                });
                Navigator.pop(ctx);
                _load();
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }
}
