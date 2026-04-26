import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/sms_parser_service.dart';
import '../services/api_service.dart';
import '../theme.dart';

class SmsConfirmationDialog extends StatefulWidget {
  final SmsTransaction transaction;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  const SmsConfirmationDialog({
    super.key,
    required this.transaction,
    required this.onConfirm,
    required this.onReject,
  });

  @override
  State<SmsConfirmationDialog> createState() => _SmsConfirmationDialogState();
}

class _SmsConfirmationDialogState extends State<SmsConfirmationDialog> {
  final ApiService _api = ApiService();
  List<dynamic> _categories = [];
  bool _loading = true;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final result = await _api.get('/categories');
      if (mounted) {
        setState(() {
          if (result is Map && result.containsKey('data')) {
            _categories = result['data'] as List;
          } else if (result is List) {
            _categories = result;
          }
          _loading = false;
          
          // Try to find the category by name
          if (_categories.isNotEmpty) {
            final matchingCategory = _categories.firstWhere(
              (cat) => cat['name']?.toString().toLowerCase() == widget.transaction.category?.toLowerCase(),
              orElse: () => null,
            );
            _selectedCategoryId = matchingCategory?['id']?.toString();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF ', decimalDigits: 0);
    
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            widget.transaction.type == 'income' ? Icons.arrow_downward : Icons.arrow_upward,
            color: widget.transaction.type == 'income' ? AppTheme.primary : AppTheme.error,
          ),
          const SizedBox(width: 8),
          const Text('Transaction détectée'),
        ],
      ),
      content: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.transaction.type == 'income' ? 'Revenu détecté' : 'Dépense détectée',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: widget.transaction.type == 'income' ? AppTheme.primary : AppTheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Montant', formatter.format(widget.transaction.amount)),
                  _buildInfoRow('Description', widget.transaction.description),
                  if (widget.transaction.sender != null) _buildInfoRow('Source', widget.transaction.sender!),
                  if (widget.transaction.balance != null) _buildInfoRow('Solde', formatter.format(widget.transaction.balance!)),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Catégorie',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat['id']?.toString(),
                        child: Text(cat['name'] ?? 'Catégorie'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategoryId = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Voulez-vous ajouter cette transaction ?',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (widget.transaction.type == 'expense')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Le montant sera déduit du budget sélectionné',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: widget.onReject,
          child: const Text('Non'),
        ),
        ElevatedButton(
          onPressed: _selectedCategoryId != null ? () => _handleConfirm(context) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.transaction.type == 'income' ? AppTheme.primary : AppTheme.tertiary,
          ),
          child: const Text('Oui, ajouter'),
        ),
      ],
    );
  }

  Future<void> _handleConfirm(BuildContext context) async {
    try {
      final data = widget.transaction.toJson();
      data['category_id'] = int.tryParse(_selectedCategoryId!);
      
      await _api.post('/transactions', data);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction ajoutée avec succès'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
      widget.onConfirm();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// Fonction pour afficher le dialogue de confirmation
Future<bool?> showSmsConfirmationDialog(
  BuildContext context,
  SmsTransaction transaction,
) async {
  return showDialog<bool>(
    context: context,
    builder: (context) => SmsConfirmationDialog(
      transaction: transaction,
      onConfirm: () => Navigator.of(context).pop(true),
      onReject: () => Navigator.of(context).pop(false),
    ),
  );
}
