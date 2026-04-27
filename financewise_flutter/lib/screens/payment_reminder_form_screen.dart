import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class PaymentReminderFormScreen extends StatefulWidget {
  final Map<String, dynamic>? paymentReminder;

  const PaymentReminderFormScreen({super.key, this.paymentReminder});

  @override
  State<PaymentReminderFormScreen> createState() => _PaymentReminderFormScreenState();
}

class _PaymentReminderFormScreenState extends State<PaymentReminderFormScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime? _dueDate;
  String _selectedFrequency = 'once';

  final List<Map<String, dynamic>> _frequencies = [
    {'value': 'once', 'label': 'Une fois'},
    {'value': 'weekly', 'label': 'Hebdomadaire'},
    {'value': 'monthly', 'label': 'Mensuel'},
    {'value': 'yearly', 'label': 'Annuel'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.paymentReminder != null) {
      _nameController.text = widget.paymentReminder!['name'] ?? '';
      _descriptionController.text = widget.paymentReminder!['description'] ?? '';
      _amountController.text = widget.paymentReminder!['amount']?.toString() ?? '';
      if (widget.paymentReminder!['due_date'] != null) {
        _dueDate = DateTime.parse(widget.paymentReminder!['due_date']);
      }
      _selectedFrequency = widget.paymentReminder!['frequency'] ?? 'once';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'name': _nameController.text,
      'description': _descriptionController.text,
      'amount': double.parse(_amountController.text),
      'due_date': _dueDate?.toIso8601String().split('T').first,
      'frequency': _selectedFrequency,
    };

    try {
      if (widget.paymentReminder != null) {
        await _api.put('/payment-reminders/${widget.paymentReminder!['id']}', data);
      } else {
        await _api.post('/payment-reminders', data);
      }
      if (mounted) Navigator.pop(context);
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
        title: Text(widget.paymentReminder != null ? 'Modifier le rappel' : 'Nouveau rappel'),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nom du rappel *',
                prefixIcon: const Icon(Icons.alarm),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Champ requis' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                prefixIcon: const Icon(Icons.notes),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Montant (FCFA) *',
                prefixIcon: const Icon(Icons.money),
                suffixText: 'FCFA',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Champ requis' : null,
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.primary, size: 20),
                ),
                title: const Text('Date d\'échéance *'),
                subtitle: Text(_dueDate != null 
                    ? DateFormat('dd MMMM yyyy', 'fr_FR').format(_dueDate!)
                    : 'Sélectionner'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _dueDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(DateTime.now().year + 5),
                  );
                  if (date != null) {
                    setState(() => _dueDate = date);
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            Text('Fréquence', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedFrequency,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.repeat),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _frequencies.map<DropdownMenuItem<String>>((freq) {
                return DropdownMenuItem<String>(
                  value: freq['value'] as String,
                  child: Text(freq['label']),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedFrequency = value);
                }
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
