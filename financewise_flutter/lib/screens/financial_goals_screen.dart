import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/offline_goal_service.dart';
import '../theme.dart';
import 'financial_goal_form_screen.dart';
import 'goal_history_screen.dart';
import 'goal_comparison_screen.dart';

class FinancialGoalsScreen extends StatefulWidget {
  const FinancialGoalsScreen({super.key});

  @override
  State<FinancialGoalsScreen> createState() => _FinancialGoalsScreenState();
}

class _FinancialGoalsScreenState extends State<FinancialGoalsScreen> {
  final _api = ApiService();
  final _offlineService = OfflineGoalService();
  List<dynamic> _goals = [];
  List<dynamic> _filteredGoals = [];
  List<dynamic> _categories = [];
  bool _loading = true;
  String? _error;
  String _selectedFilter = 'all'; // all, in_progress, completed
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _load();
    _loadCategories();
  }

  void _filterGoals() {
    setState(() {
      var filtered = _goals;

      // Filtre par statut
      if (_selectedFilter == 'in_progress') {
        filtered = filtered.where((g) => g['status'] == 'in_progress').toList();
      } else if (_selectedFilter == 'completed') {
        filtered = filtered.where((g) => g['status'] == 'completed').toList();
      }

      // Filtre par catégorie
      if (_selectedCategoryId != null) {
        filtered = filtered.where((g) => g['category_id'] == _selectedCategoryId).toList();
      }

      _filteredGoals = filtered;
    });
  }

  Future<void> _loadCategories() async {
    try {
      final result = await _api.get('/financial-goals/categories');
      if (mounted && result is Map && result['data'] is List) {
        setState(() {
          _categories = result['data'];
        });
      }
    } catch (e) {
      print('Erreur chargement catégories: $e');
    }
  }

  Future<void> _load() async {
    print('Chargement liste objectifs...');
    setState(() => _loading = true);
    
    try {
      // Essayer de charger depuis le serveur
      final result = await _api.get('/financial-goals');
      print('Résultat API: $result');
      
      if (mounted) {
        setState(() {
          _loading = false;
          if (result is Map && result['data'] is List) {
            _goals = result['data'];
            print('Objectifs chargés: ${_goals.length}');
          } else if (result is List) {
            _goals = result;
            print('Objectifs chargés (direct): ${_goals.length}');
          } else {
            print('Format de réponse invalide: $result');
            _goals = [];
          }
          _filterGoals();
        });
      }
    } catch (e) {
      print('Erreur chargement API: $e');
      // Fallback sur le mode hors ligne
      final offlineGoals = await _offlineService.getAllGoals();
      if (mounted) {
        setState(() {
          _loading = false;
          _goals = offlineGoals;
          _filterGoals();
        });
      }
    }
  }

  Future<void> _delete(int id) async {
    print('Tentative suppression objectif ID: $id');
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
    if (confirm != true) {
      print('Suppression annulée');
      return;
    }

    try {
      print('Appel API DELETE /financial-goals/$id');
      await _api.delete('/financial-goals/$id');
      print('Suppression réussie, rechargement liste');
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Objectif supprimé'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Erreur suppression: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la suppression: $e')),
        );
      }
    }
  }

  void _showCategoryFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    'Filtrer par catégorie',
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      setState(() => _selectedCategoryId = null);
                      _filterGoals();
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.clear),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ..._categories.map((cat) {
              final isSelected = _selectedCategoryId == cat['id'];
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(int.parse(cat['color'].replaceFirst('#', '0xFF'))).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIconForCategory(cat['icon']),
                    color: Color(int.parse(cat['color'].replaceFirst('#', '0xFF'))),
                    size: 20,
                  ),
                ),
                title: Text(cat['name']),
                trailing: isSelected ? const Icon(Icons.check, color: AppTheme.primary) : null,
                onTap: () {
                  setState(() => _selectedCategoryId = isSelected ? null : cat['id']);
                  _filterGoals();
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  IconData _getIconForCategory(String iconName) {
    switch (iconName) {
      case 'flight': return Icons.flight;
      case 'shopping_cart': return Icons.shopping_cart;
      case 'savings': return Icons.savings;
      case 'school': return Icons.school;
      case 'local_hospital': return Icons.local_hospital;
      case 'home': return Icons.home;
      case 'directions_car': return Icons.directions_car;
      case 'devices': return Icons.devices;
      case 'celebration': return Icons.celebration;
      case 'flag': return Icons.flag;
      default: return Icons.category;
    }
  }

  String _formatAmount(dynamic value) => AppTheme.formatCurrency(value);

  // Calculer les statistiques
  Map<String, dynamic> _getStats() {
    double totalTarget = 0;
    double totalCurrent = 0;
    int completedCount = 0;
    int inProgressCount = 0;

    for (final goal in _goals) {
      final goalTargetAmount = double.tryParse((goal['target_amount'] ?? 0).toString()) ?? 0;
      final goalCurrentAmount = double.tryParse((goal['current_amount'] ?? 0).toString()) ?? 0;
      final target = goalTargetAmount;
      final current = goalCurrentAmount;
      final status = goal['status'] ?? '';

      totalTarget += target;
      totalCurrent += current;

      if (status == 'completed') {
        completedCount++;
      } else if (status == 'in_progress') {
        inProgressCount++;
      }
    }

    double overallProgress = totalTarget > 0 ? (totalCurrent / totalTarget) * 100 : 0;

    return {
      'total_target': totalTarget,
      'total_current': totalCurrent,
      'overall_progress': overallProgress,
      'completed_count': completedCount,
      'in_progress_count': inProgressCount,
      'total_count': _goals.length,
    };
  }

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

  void _showGoalDetail(Map<dynamic, dynamic> goal) async {
    final name = goal['name'] ?? 'Objectif';
    final description = goal['description'];
    final currentAmount = double.tryParse((goal['current_amount'] ?? 0).toString()) ?? 0;
    final targetAmount = double.tryParse((goal['target_amount'] ?? 0).toString()) ?? 0;
    final remaining = targetAmount - currentAmount;
    final progress = targetAmount > 0 ? (currentAmount / targetAmount) * 100 : 0;
    final status = goal['status'] ?? '';
    final targetDate = goal['target_date'];
    final color = _getStatusColor(status);
    final icon = _goalIcon(name);

    // Charger l'épargne mensuelle recommandée
    Map<String, dynamic>? monthlySavings;
    if (targetDate != null) {
      try {
        final result = await _api.get('/financial-goals/${goal['id']}/monthly-savings');
        if (result is Map) {
          monthlySavings = Map<String, dynamic>.from(result);
        }
      } catch (e) {
        print('Erreur chargement épargne mensuelle: $e');
      }
    }

    if (!mounted) return;

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
            if (goal['category'] != null)
              _detailRow(Icons.category, 'Catégorie', goal['category']['name'] ?? ''),
            // Épargne mensuelle recommandée
            if (monthlySavings != null && monthlySavings['monthly_saving'] != null)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.savings, color: AppTheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Épargne mensuelle recommandée',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatAmount(monthlySavings['monthly_saving']),
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    if (monthlySavings['months_remaining'] != null)
                      Text(
                        'Pour atteindre l\'objectif en ${monthlySavings['months_remaining']} mois',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
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
                      _showGoalHistory(goal);
                    },
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('Historique'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showGoalHistory(Map<dynamic, dynamic> goal) async {
    setState(() => _loading = true);
    
    try {
      final result = await _api.get('/financial-goals/${goal['id']}/history');
      List<dynamic> history = [];
      
      if (result is Map && result['data'] is List) {
        history = result['data'];
      } else if (result is List) {
        history = result;
      }
      
      if (!mounted) return;
      setState(() => _loading = false);
      
      if (!mounted) return;
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
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
              const Gap(16),
              Text(
                'Historique des ajouts',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Gap(16),
              Expanded(
                child: history.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                            const SizedBox(height: 16),
                            Text('Aucun historique', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: history.length,
                        itemBuilder: (_, i) {
                          final h = history[i];
                          final amount = double.tryParse((h['amount'] ?? 0).toString()) ?? 0;
                          final isReverted = h['is_reverted'] ?? false;
                          final createdAt = h['created_at'];
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                amount >= 0 ? Icons.add_circle : Icons.remove_circle,
                                color: amount >= 0 ? AppTheme.primary : AppTheme.error,
                              ),
                              title: Text(
                                _formatAmount(amount),
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                createdAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(createdAt)) : '',
                                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                              trailing: !isReverted && amount > 0
                                  ? TextButton(
                                      onPressed: () => _revertHistory(h['id'], goal),
                                      child: const Text('Annuler'),
                                    )
                                  : isReverted
                                      ? Text(
                                          'Annulé',
                                          style: TextStyle(color: AppTheme.error, fontSize: 12),
                                        )
                                      : null,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _revertHistory(int historyId, Map<dynamic, dynamic> goal) async {
    try {
      await _api.post('/goal-histories/$historyId/revert', {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ajout annulé')),
        );
        Navigator.pop(context);
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _showAddAmountDialog(Map<dynamic, dynamic> goal) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ajouter à ${goal['name'] ?? 'cet objectif'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Montant (FCFA)',
                suffixText: 'FCFA',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Actuel: ${_formatAmount(goal['current_amount'] ?? 0)}',
              style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
            ),
            Text(
              'Objectif: ${_formatAmount(goal['target_amount'] ?? 0)}',
              style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veuillez entrer un montant valide')),
                );
                return;
              }
              
              try {
                await _api.post('/financial-goals/${goal['id']}/add-amount', {'amount': amount});
                if (mounted) {
                  Navigator.pop(ctx);
                  _load();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Montant ajouté avec succès'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e')),
                  );
                }
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
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
    final stats = _getStats();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Objectifs financiers'),
            if (!_loading && _goals.isNotEmpty)
              Text(
                '${_goals.length} objectif${_goals.length > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          if (_goals.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => GoalComparisonScreen(goals: _goals)),
                );
              },
              tooltip: 'Comparer les objectifs',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  // Section statistiques
                  if (_goals.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppTheme.softShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Épargne totale',
                                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${stats['overall_progress'].toStringAsFixed(0)}%',
                                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatAmount(stats['total_current']),
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'sur ${_formatAmount(stats['total_target'])} cible',
                            style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _StatChip(
                                icon: Icons.check_circle,
                                label: 'Atteints',
                                value: stats['completed_count'].toString(),
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              _StatChip(
                                icon: Icons.pending,
                                label: 'En cours',
                                value: stats['in_progress_count'].toString(),
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  // Filtres
                  if (_goals.isNotEmpty)
                    Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _FilterChip(
                            label: 'Tous (${stats['total_count']})',
                            isSelected: _selectedFilter == 'all',
                            onTap: () {
                              setState(() => _selectedFilter = 'all');
                              _filterGoals();
                            },
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'En cours (${stats['in_progress_count']})',
                            isSelected: _selectedFilter == 'in_progress',
                            onTap: () {
                              setState(() => _selectedFilter = 'in_progress');
                              _filterGoals();
                            },
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Atteints (${stats['completed_count']})',
                            isSelected: _selectedFilter == 'completed',
                            onTap: () {
                              setState(() => _selectedFilter = 'completed');
                              _filterGoals();
                            },
                          ),
                          const SizedBox(width: 8),
                          if (_categories.isNotEmpty) ...[
                            _CategoryFilterChip(
                              label: 'Catégories',
                              isSelected: _selectedCategoryId != null,
                              onTap: () => _showCategoryFilter(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  // Liste des objectifs
                  Expanded(
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
                                  Icon(Icons.flag_outlined, size: 64, color: cs.outlineVariant),
                                  const SizedBox(height: 16),
                                  Center(child: Text('Aucun objectif', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w500))),
                                  const SizedBox(height: 8),
                                  Center(child: Text('Définissez un objectif d\'\u00e9pargne pour commencer', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
                                  const SizedBox(height: 24),
                                  Center(
                                    child: FilledButton.icon(
                                      onPressed: () async {
                                        final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancialGoalFormScreen()));
                                        if (result == true) {
                                          _load();
                                        }
                                      },
                                      icon: const Icon(Icons.add),
                                      label: const Text('Créer un objectif'),
                                    ),
                                  ),
                                ],
                              )
                            : _filteredGoals.isEmpty
                                ? ListView(
                                    children: [
                                      const SizedBox(height: 80),
                                      Icon(Icons.filter_list_off, size: 64, color: cs.outlineVariant),
                                      const SizedBox(height: 16),
                                      Center(child: Text('Aucun objectif dans ce filtre', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w500))),
                                    ],
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                                    itemCount: _filteredGoals.length,
                                    itemBuilder: (_, i) {
                                      final goal = _filteredGoals[i];
                                      final name = goal['name'] ?? 'Objectif';
                                      final currentAmount = double.tryParse((goal['current_amount'] ?? 0).toString()) ?? 0;
                                      final targetAmount = double.tryParse((goal['target_amount'] ?? 0).toString()) ?? 0;
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
                                            child: Icon(
                                              goal['category'] != null ? _getIconForCategory(goal['category']['icon']) : Icons.category,
                                              color: Colors.white, 
                                              size: 20
                                            ),
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
                                                            backgroundColor: cs.surfaceContainerHighest,
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
                                                              Text(
                                                                'Épargné: ${_formatAmount(currentAmount)}',
                                                                style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.w700, fontSize: 14),
                                                              ),
                                                              Text(
                                                                'Reste: ${_formatAmount(remaining > 0 ? remaining : 0)}',
                                                                style: GoogleFonts.inter(color: cs.onSurfaceVariant, fontSize: 12),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            'Objectif: ${_formatAmount(targetAmount)}',
                                                            style: GoogleFonts.inter(color: cs.onSurfaceVariant, fontSize: 11),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    // Bouton d'action
                                                    Material(
                                                      color: Colors.transparent,
                                                      child: InkWell(
                                                        onTap: () => _showAddAmountDialog(goal),
                                                        borderRadius: BorderRadius.circular(12),
                                                        child: Container(
                                                          padding: const EdgeInsets.all(10),
                                                          decoration: BoxDecoration(
                                                            color: cs.primaryContainer,
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                                          child: Icon(Icons.add, size: 20, color: cs.primary),
                                                        ),
                                                      ),
                                                    ),
                                                    Icon(Icons.chevron_right, color: cs.outlineVariant, size: 18),
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
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          print('Ouverture formulaire création objectif');
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancialGoalFormScreen()));
          print('Résultat formulaire: $result');
          if (result == true) {
            print('Rechargement liste objectifs');
            _load();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Objectif'),
      ),
    );
  }

  void _showEditAmountDialog(dynamic goal) {
    final controller = TextEditingController(text: double.tryParse((goal['current_amount'] ?? 0).toString())?.toStringAsFixed(0) ?? '0');
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Modifier le montant de ${goal['name'] ?? 'cet objectif'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Montant actuel (FCFA)',
                prefixText: 'FCFA ',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount == null || amount < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veuillez entrer un montant valide')),
                );
                return;
              }
              
              try {
                await _api.put('/financial-goals/${goal['id']}', {
                  'current_amount': amount,
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  _load();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Montant mis à jour: ${_formatAmount(amount)}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e')),
                  );
                }
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (isSelected) const SizedBox(width: 4),
          if (isSelected) const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.primary.withValues(alpha: 0.2),
      checkmarkColor: AppTheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.primary : Theme.of(context).colorScheme.outlineVariant,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.primary.withValues(alpha: 0.2),
      checkmarkColor: AppTheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.primary : Theme.of(context).colorScheme.outlineVariant,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
