import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';

class WalletFormScreen extends StatefulWidget {
  final Map<String, dynamic>? wallet;
  const WalletFormScreen({super.key, this.wallet});

  @override
  State<WalletFormScreen> createState() => _WalletFormScreenState();
}

class _WalletFormScreenState extends State<WalletFormScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();

  bool _saving = false;
  String? _error;

  String _type = 'mobile_money';
  String _currency = 'XOF';

  bool get _isEdit => widget.wallet != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final w = widget.wallet!;
      _nameCtrl.text = w['name']?.toString() ?? '';
      _balanceCtrl.text = w['balance']?.toString() ?? '';
      _type = w['type'] ?? 'mobile_money';
      _currency = w['currency'] ?? 'XOF';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final body = {
      'name': _nameCtrl.text.trim(),
      'balance': double.tryParse(_balanceCtrl.text) ?? 0,
      'type': _type,
      'currency': _currency,
    };

    final result = _isEdit
        ? await _api.put('/wallets/${widget.wallet!['id']}', body)
        : await _api.post('/wallets', body);

    setState(() => _saving = false);
    if (result != null && result is Map && (result.containsKey('data') || result.containsKey('id'))) {
      // Notification de succès
      await NotificationService().showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: _isEdit ? 'Wallet modifié' : 'Wallet créé',
        body: '${_nameCtrl.text}: ${_balanceCtrl.text} $_currency',
      );
      if (mounted) Navigator.pop(context);
    } else {
      setState(() => _error = result?['message'] ?? 'Erreur lors de l\'enregistrement');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Modifier Wallet' : 'Nouveau Wallet')),
      body: SingleChildScrollView(
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
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nom du wallet',
                  prefixIcon: const Icon(Icons.label),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v != null && v.isNotEmpty ? null : 'Nom requis',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _balanceCtrl,
                decoration: InputDecoration(
                  labelText: 'Solde initial',
                  prefixIcon: const Icon(Icons.money),
                  suffixText: _currency,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.number,
                enabled: !_isEdit,
                validator: (v) => v != null && v.isNotEmpty ? null : 'Solde requis',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: InputDecoration(
                  labelText: 'Type',
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'mobile_money', child: Text('Mobile Money')),
                  DropdownMenuItem(value: 'bank', child: Text('Banque')),
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                ],
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _currency,
                decoration: InputDecoration(
                  labelText: 'Devise',
                  prefixIcon: const Icon(Icons.currency_exchange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'XOF', child: Text('FCFA')),
                  DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                  DropdownMenuItem(value: 'USD', child: Text('USD')),
                ],
                onChanged: (v) => setState(() => _currency = v!),
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
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }
}
