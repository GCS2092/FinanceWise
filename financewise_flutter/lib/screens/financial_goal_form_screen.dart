import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme.dart';

class FinancialGoalFormScreen extends StatefulWidget {
  final Map<String, dynamic>? financialGoal;

  const FinancialGoalFormScreen({super.key, this.financialGoal});

  @override
  State<FinancialGoalFormScreen> createState() => _FinancialGoalFormScreenState();
}

class _FinancialGoalFormScreenState extends State<FinancialGoalFormScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _currentAmountController = TextEditingController();
  DateTime? _targetDate;
  String _selectedIcon = 'savings';
  String _selectedColor = '#4CAF50';

  final List<Map<String, dynamic>> _icons = [
    {'icon': Icons.savings, 'name': 'savings'},
    {'icon': Icons.home, 'name': 'home'},
    {'icon': Icons.directions_car, 'name': 'car'},
    {'icon': Icons.school, 'name': 'education'},
    {'icon': Icons.flight, 'name': 'vacation'},
    {'icon': Icons.phone, 'name': 'phone'},
    {'icon': Icons.shopping_bag, 'name': 'shopping'},
    {'icon': Icons.health_and_safety, 'name': 'health'},
  ];

  final List<Map<String, dynamic>> _colors = [
    {'color': '#4CAF50', 'name': 'Vert'},
    {'color': '#2196F3', 'name': 'Bleu'},
    {'color': '#FF9800', 'name': 'Orange'},
    {'color': '#9C27B0', 'name': 'Violet'},
    {'color': '#F44336', 'name': 'Rouge'},
    {'color': '#607D8B', 'name': 'Gris'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.financialGoal != null) {
      _nameController.text = widget.financialGoal!['name'] ?? '';
      _descriptionController.text = widget.financialGoal!['description'] ?? '';
      _targetAmountController.text = widget.financialGoal!['target_amount']?.toString() ?? '';
      _currentAmountController.text = widget.financialGoal!['current_amount']?.toString() ?? '';
      if (widget.financialGoal!['target_date'] != null) {
        _targetDate = DateTime.parse(widget.financialGoal!['target_date']);
      }
      _selectedIcon = widget.financialGoal!['icon'] ?? 'savings';
      _selectedColor = widget.financialGoal!['color'] ?? '#4CAF50';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _targetAmountController.dispose();
    _currentAmountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'name': _nameController.text,
      'description': _descriptionController.text,
      'target_amount': double.parse(_targetAmountController.text),
      'current_amount': _currentAmountController.text.isEmpty ? 0 : double.parse(_currentAmountController.text),
      'target_date': _targetDate?.toIso8601String().split('T').first,
      'icon': _selectedIcon,
      'color': _selectedColor,
    };

    try {
      if (widget.financialGoal != null) {
        await _api.put('/financial-goals/${widget.financialGoal!['id']}', data);
      } else {
        await _api.post('/financial-goals', data);
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
        title: Text(widget.financialGoal != null ? 'Modifier l\'objectif' : 'Nouvel objectif'),
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
                labelText: 'Nom de l\'objectif *',
                prefixIcon: const Icon(Icons.flag),
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
              controller: _targetAmountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Montant cible (FCFA) *',
                prefixIcon: const Icon(Icons.money),
                suffixText: 'FCFA',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Champ requis' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _currentAmountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Montant actuel (FCFA)',
                prefixIcon: const Icon(Icons.account_balance_wallet),
                suffixText: 'FCFA',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
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
                title: const Text('Date cible'),
                subtitle: Text(_targetDate != null 
                    ? DateFormat('dd MMMM yyyy', 'fr_FR').format(_targetDate!)
                    : 'Sélectionner'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _targetDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(DateTime.now().year + 10),
                  );
                  if (date != null) {
                    setState(() => _targetDate = date);
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            Text('Icône', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _icons.map((iconData) {
                return ChoiceChip(
                  label: Icon(iconData['icon']),
                  selected: _selectedIcon == iconData['name'],
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedIcon = iconData['name']);
                    }
                  },
                  selectedColor: AppTheme.primary.withValues(alpha: 0.15),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('Couleur', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _colors.map((colorData) {
                return ChoiceChip(
                  label: Text(colorData['name']),
                  selected: _selectedColor == colorData['color'],
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedColor = colorData['color']);
                    }
                  },
                  selectedColor: Color(int.parse(colorData['color'].replaceAll('#', '0xFF'))).withValues(alpha: 0.2),
                );
              }).toList(),
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
