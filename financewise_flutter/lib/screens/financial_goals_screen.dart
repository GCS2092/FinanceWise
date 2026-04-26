import 'package:flutter/material.dart';
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

  String _formatAmount(dynamic value) {
    final amount = (value ?? 0).toDouble();
    return NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF ', decimalDigits: 0).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Objectifs financiers'),
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
                            final currentAmount = goal['current_amount'] ?? 0;
                            final targetAmount = goal['target_amount'] ?? 0;
                            final remaining = targetAmount - currentAmount;
                            final progress = targetAmount > 0 ? (currentAmount / targetAmount) * 100 : 0;

                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              margin: const EdgeInsets.only(bottom: 16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => FinancialGoalFormScreen(financialGoal: goal)),
                                  );
                                  _load();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              goal['name'] ?? 'Objectif',
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                            onPressed: () => _delete(goal['id']),
                                          ),
                                        ],
                                      ),
                                      if (goal['description'] != null)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: Text(
                                            goal['description'],
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 12),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: LinearProgressIndicator(
                                          value: progress / 100,
                                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                          valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor(goal['status'])),
                                          minHeight: 8,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('${progress.toStringAsFixed(0)}%'),
                                          Text('${_formatAmount(currentAmount)} / ${_formatAmount(targetAmount)}'),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Reste: ${_formatAmount(remaining)}',
                                        style: TextStyle(
                                          color: remaining <= 0 ? AppTheme.primary : Colors.orange,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (goal['target_date'] != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            'Date cible: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(goal['target_date']))}',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                          ),
                                        ),
                                      const SizedBox(height: 12),
                                      ElevatedButton.icon(
                                        onPressed: () => _showAddAmountDialog(goal),
                                        icon: const Icon(Icons.add),
                                        label: const Text('Ajouter un montant'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancialGoalFormScreen()));
          _load();
        },
        child: const Icon(Icons.add),
      ),
    );
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
            labelText: 'Montant (XOF)',
            suffixText: 'XOF',
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
