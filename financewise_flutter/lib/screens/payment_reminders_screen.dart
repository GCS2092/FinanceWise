import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
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

  String _formatAmount(dynamic value) {
    final amount = (value ?? 0).toDouble();
    return NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF ', decimalDigits: 0).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rappels de paiement'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _error != null
                  ? ListView(
                      children: [SizedBox(height: 200), Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))],
                    )
                  : _reminders.isEmpty
                      ? ListView(
                          children: const [SizedBox(height: 200), Center(child: Text('Aucun rappel', style: TextStyle(color: Colors.grey)))],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _reminders.length,
                          itemBuilder: (_, i) {
                            final reminder = _reminders[i];
                            final dueDate = DateTime.parse(reminder['due_date']);
                            final daysUntilDue = dueDate.difference(DateTime.now()).inDays;
                            final isOverdue = daysUntilDue < 0;
                            final isCompleted = reminder['status'] == 'completed';

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
                                    MaterialPageRoute(builder: (_) => PaymentReminderFormScreen(paymentReminder: reminder)),
                                  );
                                  _load();
                                },
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: CircleAvatar(
                                    radius: 24,
                                    backgroundColor: isCompleted 
                                        ? Colors.green.withValues(alpha: 0.15)
                                        : isOverdue
                                            ? Colors.red.withValues(alpha: 0.15)
                                            : Colors.orange.withValues(alpha: 0.15),
                                    child: Icon(
                                      isCompleted ? Icons.check : isOverdue ? Icons.warning : Icons.notification_important,
                                      color: isCompleted ? Colors.green : isOverdue ? Colors.red : Colors.orange,
                                      size: 24,
                                    ),
                                  ),
                                  title: Text(
                                    reminder['name'] ?? 'Rappel',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text('${_formatAmount(reminder['amount'])}'),
                                      Text('Date: ${DateFormat('dd/MM/yyyy').format(dueDate)}'),
                                      Text('Fréquence: ${_getFrequencyLabel(reminder['frequency'])}'),
                                      if (!isCompleted)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            isOverdue 
                                                ? 'En retard de ${daysUntilDue.abs()} jours'
                                                : daysUntilDue == 0 
                                                    ? 'Aujourd\'hui'
                                                    : 'Dans $daysUntilDue jours',
                                            style: TextStyle(
                                              color: isOverdue ? Colors.red : Colors.orange,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isCompleted)
                                        IconButton(
                                          icon: const Icon(Icons.check_circle, color: Colors.green),
                                          onPressed: () => _markCompleted(reminder),
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.grey),
                                        onPressed: () => _delete(reminder['id']),
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
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentReminderFormScreen()));
          _load();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

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
}
