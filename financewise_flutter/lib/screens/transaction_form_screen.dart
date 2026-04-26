import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class TransactionFormScreen extends StatefulWidget {
  final Map<String, dynamic>? transaction;
  const TransactionFormScreen({super.key, this.transaction});

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  List<dynamic> _wallets = [];
  List<dynamic> _categories = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  int? _walletId;
  int? _categoryId;
  String _type = 'expense';
  DateTime _date = DateTime.now();

  bool get _isEdit => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final w = await _api.get('/wallets');
    final c = await _api.get('/categories');

    setState(() {
      _wallets = (w is Map && w.containsKey('data')) ? w['data'] : (w is List ? w : []);
      _categories = (c is Map && c.containsKey('data')) ? c['data'] : (c is List ? c : []);
      _loading = false;

      if (_wallets.isNotEmpty && _walletId == null) _walletId = _wallets.first['id'];
      if (_categories.isNotEmpty && _categoryId == null) _categoryId = _categories.first['id'];

      if (_isEdit) {
        final t = widget.transaction!;
        _amountCtrl.text = t['amount'].toString();
        _descCtrl.text = t['description']?.toString() ?? '';
        _walletId = t['wallet_id'];
        _categoryId = t['category_id'];
        _type = t['type'] ?? 'expense';
        final d = DateTime.tryParse(t['transaction_date']?.toString() ?? '');
        if (d != null) _date = d;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_walletId == null || _categoryId == null) {
      setState(() => _error = 'Sélectionne un wallet et une catégorie');
      return;
    }
    setState(() => _saving = true);

    final body = {
      'wallet_id': _walletId,
      'category_id': _categoryId,
      'type': _type,
      'amount': double.tryParse(_amountCtrl.text) ?? 0,
      'description': _descCtrl.text,
      'transaction_date': DateFormat('yyyy-MM-dd').format(_date),
      'source': 'manual',
    };

    final result = _isEdit
        ? await _api.put('/transactions/${widget.transaction!['id']}', body)
        : await _api.post('/transactions', body);

    setState(() => _saving = false);
    if (result != null && result is Map && (result.containsKey('data') || result.containsKey('id'))) {
      // Notification de succès
      await NotificationService().showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: _isEdit ? 'Transaction modifiée' : 'Transaction créée',
        body: '${_type == 'income' ? 'Revenu' : 'Dépense'} de ${_amountCtrl.text} XOF',
      );
      if (mounted) Navigator.pop(context);
    } else {
      setState(() => _error = result?['message'] ?? 'Erreur lors de l\'enregistrement');
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (d != null) setState(() => _date = d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Modifier Transaction' : 'Nouvelle Transaction')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'income', label: Text('Revenu'), icon: Icon(Icons.arrow_upward)),
                        ButtonSegment(value: 'expense', label: Text('Dépense'), icon: Icon(Icons.arrow_downward)),
                      ],
                      selected: {_type},
                      onSelectionChanged: (s) => setState(() => _type = s.first),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountCtrl,
                      decoration: const InputDecoration(labelText: 'Montant', prefixIcon: Icon(Icons.money)),
                      keyboardType: TextInputType.number,
                      validator: (v) => v != null && v.isNotEmpty ? null : 'Montant requis',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descCtrl,
                      decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.notes)),
                      validator: (v) => v != null && v.isNotEmpty ? null : 'Description requise',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _walletId,
                      decoration: const InputDecoration(labelText: 'Wallet', prefixIcon: Icon(Icons.account_balance_wallet)),
                      items: _wallets.map<DropdownMenuItem<int>>((w) => DropdownMenuItem(value: w['id'] as int, child: Text('${w['name']} (${w['balance']} ${w['currency'] ?? 'XOF'})'))).toList(),
                      onChanged: (v) => setState(() => _walletId = v),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _categoryId,
                      decoration: const InputDecoration(labelText: 'Catégorie', prefixIcon: Icon(Icons.category)),
                      items: _categories.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['name']))).toList(),
                      onChanged: (v) => setState(() => _categoryId = v),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Date'),
                      subtitle: Text('${_date.day}/${_date.month}/${_date.year}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
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
    _descCtrl.dispose();
    super.dispose();
  }
}
