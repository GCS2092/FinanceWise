import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/ai_service.dart';
import '../services/notification_service.dart';
import '../services/logger_service.dart';
import '../theme.dart';

class TransactionFormScreen extends StatefulWidget {
  final Map<String, dynamic>? transaction;
  const TransactionFormScreen({super.key, this.transaction});

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _api = ApiService();
  final _ai = AiService();
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

  // IA - suggestion de catégorie
  Timer? _aiDebounce;
  bool _aiSuggesting = false;
  int? _aiSuggestedCategoryId;
  String? _aiSuggestedCategoryName;
  String _aiLastQueriedDescription = '';

  bool get _isEdit => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR');
    _loadData();
    _descCtrl.addListener(_onDescriptionChanged);
  }

  void _onDescriptionChanged() {
    if (_isEdit) return; // pas de suggestion en édition
    _aiDebounce?.cancel();
    _aiDebounce = Timer(const Duration(milliseconds: 800), _requestAiSuggestion);
  }

  Future<void> _requestAiSuggestion() async {
    final desc = _descCtrl.text.trim();
    if (desc.length < 3 || desc == _aiLastQueriedDescription) return;
    _aiLastQueriedDescription = desc;

    setState(() => _aiSuggesting = true);
    final s = await _ai.suggestCategory(description: desc, type: _type);
    if (!mounted) return;

    if (s?.categoryId != null && _categories.any((c) => c['id'] == s!.categoryId)) {
      setState(() {
        _aiSuggesting = false;
        _aiSuggestedCategoryId = s!.categoryId;
        _aiSuggestedCategoryName = s.categoryName;
        // Pré-remplir si l'utilisateur n'a pas encore choisi manuellement
        _categoryId ??= s.categoryId;
      });
    } else {
      setState(() => _aiSuggesting = false);
    }
  }

  void _applyAiSuggestion() {
    if (_aiSuggestedCategoryId != null) {
      setState(() => _categoryId = _aiSuggestedCategoryId);
    }
  }

  Future<void> _loadData() async {
    final w = await _api.get('/wallets');
    final c = await _api.get('/categories');

    setState(() {
      _wallets = (w is Map && w.containsKey('data')) ? w['data'] : (w is List ? w : []);
      _categories = (c is Map && c.containsKey('data')) ? c['data'] : (c is List ? c : []);
      _loading = false;

      if (_isEdit) {
        final t = widget.transaction!;
        _amountCtrl.text = t['amount'].toString();
        _descCtrl.text = t['description']?.toString() ?? '';
        _walletId = t['wallet_id'];
        _categoryId = t['category_id'];
        _type = t['type'] ?? 'expense';
        final d = DateTime.tryParse(t['transaction_date']?.toString() ?? '');
        if (d != null) _date = d;
      } else {
        // Valeurs par défaut uniquement pour la création
        if (_wallets.isNotEmpty && _walletId == null) _walletId = _wallets.first['id'];
        if (_categories.isNotEmpty && _categoryId == null) _categoryId = _categories.first['id'];
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

    // Apprentissage IA : l'utilisateur a changé la catégorie suggérée
    if (!_isEdit &&
        _aiSuggestedCategoryId != null &&
        _categoryId != null &&
        _aiSuggestedCategoryId != _categoryId &&
        _descCtrl.text.trim().isNotEmpty) {
      unawaited(_ai.learnCorrection(
        description: _descCtrl.text.trim(),
        categoryId: _categoryId!,
      ));
    }

    setState(() => _saving = false);
    if (result != null && result is Map && (result.containsKey('data') || result.containsKey('id'))) {
      // Notification de succès
      await NotificationService().showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: _isEdit ? 'Transaction modifiée' : 'Transaction créée',
        body: '${_type == 'income' ? 'Revenu' : 'Dépense'} de ${_amountCtrl.text} FCFA',
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
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
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
                    const SizedBox(height: 16),
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
                      decoration: InputDecoration(
                        labelText: 'Montant *',
                        prefixIcon: const Icon(Icons.money),
                        suffixText: 'FCFA',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => v != null && v.isNotEmpty ? null : 'Montant requis',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descCtrl,
                      decoration: InputDecoration(
                        labelText: 'Description *',
                        prefixIcon: const Icon(Icons.notes),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v != null && v.isNotEmpty ? null : 'Description requise',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _walletId,
                      decoration: InputDecoration(
                        labelText: 'Wallet',
                        prefixIcon: const Icon(Icons.account_balance_wallet),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _wallets.map<DropdownMenuItem<int>>((w) => DropdownMenuItem(value: w['id'] as int, child: Text('${w['name']} (${AppTheme.formatCurrency(w['balance'])})'))).toList(),
                      onChanged: (v) => setState(() => _walletId = v),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _categoryId,
                      decoration: InputDecoration(
                        labelText: 'Catégorie',
                        prefixIcon: const Icon(Icons.category),
                        suffixIcon: _aiSuggesting
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5)),
                              )
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _categories.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['name']))).toList(),
                      onChanged: (v) => setState(() => _categoryId = v),
                    ),
                    if (_aiSuggestedCategoryName != null && _categoryId != _aiSuggestedCategoryId) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _applyAiSuggestion,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.auto_awesome_rounded, size: 16, color: AppTheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Suggestion IA : $_aiSuggestedCategoryName',
                                  style: TextStyle(fontSize: 12.5, color: AppTheme.primary, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text('Appliquer', style: TextStyle(fontSize: 11.5, color: AppTheme.primary, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ],
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
                        title: const Text('Date'),
                        subtitle: Text(DateFormat('dd MMMM yyyy', 'fr_FR').format(_date)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _pickDate,
                      ),
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
    _aiDebounce?.cancel();
    _descCtrl.removeListener(_onDescriptionChanged);
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }
}
