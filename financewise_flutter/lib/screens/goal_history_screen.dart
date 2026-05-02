import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/offline_goal_service.dart';
import '../theme.dart';

class GoalHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> goal;
  const GoalHistoryScreen({super.key, required this.goal});

  @override
  State<GoalHistoryScreen> createState() => _GoalHistoryScreenState();
}

class _GoalHistoryScreenState extends State<GoalHistoryScreen> {
  final _api = ApiService();
  final _offlineService = OfflineGoalService();
  List<dynamic> _history = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    
    try {
      final goalId = widget.goal['id'];
      final history = await _offlineService.getGoalHistory(goalId);
      
      if (mounted) {
        setState(() {
          _history = history;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur lors du chargement de l\'historique';
          _loading = false;
        });
      }
    }
  }

  String _formatAmount(dynamic value) => AppTheme.formatCurrency(value);

  Future<void> _revertHistory(Map<String, dynamic> historyItem) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler cet ajout ?'),
        content: Text('Voulez-vous annuler l\'ajout de ${_formatAmount(historyItem['amount'])} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await _api.post('/goal-histories/${historyItem['id']}/revert', {});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ajout annulé avec succès')),
        );
        _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Historique'),
            Text(
              widget.goal['name'] ?? 'Objectif',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ListView(
                  children: [
                    const SizedBox(height: 100),
                    const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                    const SizedBox(height: 12),
                    Center(child: Text(_error!, style: const TextStyle(color: AppTheme.error))),
                  ],
                )
              : _history.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 80),
                        Icon(Icons.history, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                        const SizedBox(height: 16),
                        Center(child: Text('Aucun historique', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500))),
                        const SizedBox(height: 8),
                        Center(child: Text('Les ajouts d\'argent apparaîtront ici', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _history.length,
                      itemBuilder: (_, i) {
                        final item = _history[i];
                        final amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0;
                        final type = item['type'] ?? 'add';
                        final isAdd = type == 'add';
                        final isReverted = item['is_reverted'] == true;
                        final createdAt = item['created_at'];
                        final isOffline = item['_offline'] == true;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isReverted ? Colors.grey.shade100 : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: isOffline ? Border.all(color: AppTheme.primary.withOpacity(0.3)) : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isReverted 
                                      ? Colors.grey.shade300
                                      : isAdd 
                                          ? AppTheme.primary.withOpacity(0.1)
                                          : AppTheme.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isAdd ? Icons.add : Icons.remove,
                                  color: isReverted 
                                      ? Colors.grey
                                      : isAdd 
                                          ? AppTheme.primary
                                          : AppTheme.error,
                                ),
                              ),
                              const Gap(16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isAdd ? 'Ajout' : 'Retrait',
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                    if (createdAt != null)
                                      Text(
                                        DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.parse(createdAt)),
                                        style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                      ),
                                    if (isOffline)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Hors ligne',
                                          style: GoogleFonts.inter(fontSize: 10, color: AppTheme.primary),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatAmount(amount),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: isReverted 
                                          ? Colors.grey
                                          : isAdd 
                                              ? AppTheme.primary
                                              : AppTheme.error,
                                    ),
                                  ),
                                  if (isReverted)
                                    Text(
                                      'Annulé',
                                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                                    ),
                                  if (!isReverted && !isOffline && isAdd)
                                    TextButton(
                                      onPressed: () => _revertHistory(item),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(0, 24),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text('Annuler', style: TextStyle(fontSize: 11, color: AppTheme.error)),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
