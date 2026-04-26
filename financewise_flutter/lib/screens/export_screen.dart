import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _transactions = [];
  bool _loading = false;
  bool _exporting = false;
  String? _error;

  Future<void> _loadTransactions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.get('/transactions');
      final data = result is Map ? (result['data'] ?? result) : result;
      setState(() {
        _transactions = data is List ? data : [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _exportToCsv() async {
    setState(() => _exporting = true);
    try {
      final csv = 'Date,Description,Catégorie,Type,Montant\n' +
          _transactions.map((t) {
            final date = t['transaction_date'] ?? '';
            final desc = (t['description'] ?? '').toString().replaceAll(',', ' ');
            final cat = t['category'] is Map ? (t['category']['name'] ?? '') : '';
            final type = t['type'] ?? '';
            final amount = t['amount'] ?? 0;
            return '$date,$desc,$cat,$type,$amount';
          }).join('\n');
      await Clipboard.setData(ClipboardData(text: csv));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV copié dans le presse-papier')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      setState(() => _exporting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Transactions à exporter: ${_transactions.length}'),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _exporting || _transactions.isEmpty ? null : _exportToCsv,
                                  icon: _exporting
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.copy),
                                  label: Text(_exporting ? 'Exportation...' : 'Copier en CSV'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text('Le CSV sera copié dans le presse-papier', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Aperçu des données:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _transactions.length,
                        itemBuilder: (ctx, i) {
                          final t = _transactions[i];
                          return ListTile(
                            dense: true,
                            title: Text(t['description'] ?? ''),
                            subtitle: Text('${t['transaction_date']} • ${t['type']} • ${t['amount']}'),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
