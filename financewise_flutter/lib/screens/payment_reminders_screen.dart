import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'payment_reminder_form_screen.dart';

class PaymentRemindersScreen extends StatefulWidget {
  const PaymentRemindersScreen({super.key});

  @override
  State<PaymentRemindersScreen> createState() => _PaymentRemindersScreenState();
}

class _PaymentRemindersScreenState extends State<PaymentRemindersScreen> {
  final _api = ApiService();
  List<dynamic> _reminders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _api.get('/payment-reminders');
    if (mounted) {
      setState(() {
        _loading = false;
        if (result is Map && result.containsKey('data')) {
          _reminders = result['data'] as List;
        } else if (result is List) {
          _reminders = result;
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
        content: const Text('Ce rappel sera définitivement supprimé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirm != true) return;

    await _api.delete('/payment-reminders/$id');
    _load();
  }

  Future<void> _markCompleted(dynamic reminder) async {
    await _api.post('/payment-reminders/${reminder['id']}/mark-completed', {});
    _load();
  }

  String _formatAmount(dynamic value) => AppTheme.formatCurrency(value);

  String _getFrequencyLabel(String? frequency) {
    switch (frequency) {
      case 'once':
        return 'Une fois';
      case 'weekly':
        return 'Hebdomadaire';
      case 'monthly':
        return 'Mensuel';
      case 'yearly':
        return 'Annuel';
      default:
        return 'Inconnu';
    }
  }

  void _showReminderDetail(Map<dynamic, dynamic> reminder) {
    final name = reminder['name'] ?? 'Rappel';
    final amount = reminder['amount'];
    final dueDate = DateTime.parse(reminder['due_date']);
    final frequency = reminder['frequency'];
    final daysUntilDue = dueDate.difference(DateTime.now()).inDays;
    final isOverdue = daysUntilDue < 0;
    final isCompleted = reminder['status'] == 'completed';
    final color = isCompleted ? AppTheme.primary : (isOverdue ? AppTheme.error : Colors.orange);
    final icon = isCompleted ? Icons.check_circle : (isOverdue ? Icons.warning : Icons.notification_important);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: Colors.white70, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(_formatAmount(amount), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(DateFormat('dd/MM/yyyy').format(dueDate), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _detailRow(Icons.attach_money, 'Montant', _formatAmount(amount)),
            _detailRow(Icons.calendar_today, 'Date échéance', DateFormat('dd/MM/yyyy').format(dueDate)),
            _detailRow(Icons.repeat, 'Fréquence', _getFrequencyLabel(frequency)),
            _detailRow(
              Icons.info_outline,
              'Statut',
              isCompleted ? 'Complété' : (isOverdue ? 'En retard' : 'À venir'),
              valueColor: color,
            ),
            if (!isCompleted) ...[
              _detailRow(
                Icons.access_time,
                'Jours restants',
                isOverdue ? '${daysUntilDue.abs()} jours de retard' : (daysUntilDue == 0 ? 'Aujourd\'hui' : '$daysUntilDue jours'),
                valueColor: isOverdue ? AppTheme.error : Colors.orange,
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentReminderFormScreen(paymentReminder: Map<String, dynamic>.from(reminder)))).then((_) => _load());
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Modifier'),
                  ),
                ),
                const SizedBox(width: 12),
                if (!isCompleted)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _markCompleted(reminder);
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Compléter'),
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _delete(reminder['id']);
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          const Spacer(),
          Text(value, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: valueColor)),
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
            const Text('Rappels de paiement'),
            if (!_loading && _reminders.isNotEmpty)
              Text(
                '${_reminders.length} rappel${_reminders.length > 1 ? 's' : ''}',
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
                  : _reminders.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            Icon(Icons.alarm_off, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                            const SizedBox(height: 16),
                            Center(child: Text('Aucun rappel', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500))),
                            const SizedBox(height: 8),
                            Center(child: Text('Créez un rappel pour ne manquer aucun paiement', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _reminders.length,
                          itemBuilder: (_, i) {
                            final reminder = _reminders[i];
                            final name = reminder['name'] ?? 'Rappel';
                            final amount = reminder['amount'];
                            final dueDate = DateTime.parse(reminder['due_date']);
                            final frequency = reminder['frequency'];
                            final daysUntilDue = dueDate.difference(DateTime.now()).inDays;
                            final isOverdue = daysUntilDue < 0;
                            final isCompleted = reminder['status'] == 'completed';
                            final color = isCompleted ? AppTheme.primary : (isOverdue ? AppTheme.error : Colors.orange);
                            final icon = isCompleted ? Icons.check_circle : (isOverdue ? Icons.warning : Icons.notification_important);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Dismissible(
                                key: Key(reminder['id'].toString()),
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
                                      content: const Text('Ce rappel sera définitivement supprimé.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) await _delete(reminder['id']);
                                  return false;
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isCompleted ? null : color.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(14),
                                    border: isCompleted ? null : Border.all(color: color.withValues(alpha: 0.3), width: 1),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(14),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () => _showReminderDetail(reminder),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: color.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Icon(icon, color: color, size: 24),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                      fontWeight: isCompleted ? FontWeight.normal : FontWeight.w600,
                                                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Wrap(
                                                    spacing: 8,
                                                    crossAxisAlignment: WrapCrossAlignment.center,
                                                    children: [
                                                      Text(_formatAmount(amount), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                                                      Text(DateFormat('dd/MM/yyyy').format(dueDate), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: color.withValues(alpha: 0.1),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(_getFrequencyLabel(frequency), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                                                      ),
                                                    ],
                                                  ),
                                                  if (!isCompleted) ...[
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      isOverdue ? 'En retard de ${daysUntilDue.abs()} jours' : (daysUntilDue == 0 ? 'Aujourd\'hui' : 'Dans $daysUntilDue jours'),
                                                      style: TextStyle(fontSize: 11, color: isOverdue ? AppTheme.error : Colors.orange, fontWeight: FontWeight.w500),
                                                    ),
                                                  ],
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
                            ),
                          );
                        },
                        ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentReminderFormScreen()));
          _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Rappel'),
      ),
    );
  }
}
