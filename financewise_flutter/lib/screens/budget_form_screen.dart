import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';

class BudgetFormScreen extends StatefulWidget {
  final Map<String, dynamic>? budget;
  const BudgetFormScreen({super.key, this.budget});

  @override
  State<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends State<BudgetFormScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();

  List<dynamic> _categories = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  int? _categoryId;
  String _period = 'monthly';

  bool get _isEdit => widget.budget != null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final c = await _api.get('/categories');
    setState(() {
      _categories = (c is Map && c.containsKey('data')) ? c['data'] : (c is List ? c : []);
      _loading = false;

      if (_categories.isNotEmpty && _categoryId == null) _categoryId = _categories.first['id'];

      if (_isEdit) {
        final b = widget.budget!;
        _amountCtrl.text = b['amount'].toString();
        _categoryId = b['category_id'];
        _period = b['period'] ?? 'monthly';
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      setState(() => _error = 'Sélectionne une catégorie');
      return;
    }
    setState(() => _saving = true);

    final now = DateTime.now();
    final body = {
      'category_id': _categoryId,
      'amount': double.tryParse(_amountCtrl.text) ?? 0,
      'period': _period,
      'start_date': DateTime(now.year, now.month, 1).toIso8601String().split('T').first,
      'end_date': DateTime(now.year, now.month + 1, 0).toIso8601String().split('T').first,
      'is_active': true,
    };

    final result = _isEdit
        ? await _api.put('/budgets/${widget.budget!['id']}', body)
        : await _api.post('/budgets', body);

    setState(() => _saving = false);
    if (result != null && result is Map && (result.containsKey('data') || result.containsKey('id'))) {
      // Notification de succès
      await NotificationService().showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: _isEdit ? 'Budget modifié' : 'Budget créé',
        body: 'Budget de ${_amountCtrl.text} FCFA pour la catégorie sélectionnée',
      );
      if (mounted) Navigator.pop(context);
    } else {
      setState(() => _error = result?['message'] ?? 'Erreur lors de l\'enregistrement');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Modifier Budget' : 'Nouveau Budget')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  children: [
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.error))),
                          ],
                        ),
                      ),
                    DropdownButtonFormField<int>(
                      value: _categoryId,
                      decoration: InputDecoration(
                        labelText: 'Catégorie',
                        prefixIcon: const Icon(Icons.category),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _categories
                          .where((c) => c['type'] == 'expense' || c['type'] == 'financial_goal')
                          .map<DropdownMenuItem<int>>((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['name'])))
                          .toList(),
                      onChanged: (v) => setState(() => _categoryId = v),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountCtrl,
                      decoration: InputDecoration(
                        labelText: 'Montant budget',
                        prefixIcon: const Icon(Icons.money),
                        suffixText: 'FCFA',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v != null && v.isNotEmpty ? null : 'Montant requis',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _period,
                      decoration: InputDecoration(
                        labelText: 'Période',
                        prefixIcon: const Icon(Icons.calendar_view_month),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'weekly', child: Text('Hebdomadaire')),
                        DropdownMenuItem(value: 'monthly', child: Text('Mensuel')),
                        DropdownMenuItem(value: 'yearly', child: Text('Annuel')),
                      ],
                      onChanged: (v) => setState(() => _period = v!),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(_isEdit ? 'Enregistrer' : 'Créer'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }
}
