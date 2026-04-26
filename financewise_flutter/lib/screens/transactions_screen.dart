import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/onboarding_tooltip.dart';
import '../theme.dart';
import 'transaction_form_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _api = ApiService();
  List<dynamic> _transactions = [];
  List<dynamic> _filteredTransactions = [];
  bool _loading = true;
  String? _error;
  final GlobalKey<OnboardingTooltipState> _tooltipKey = GlobalKey<OnboardingTooltipState>();
  
  // Filtres
  String _searchQuery = '';
  String? _selectedType;
  String? _selectedCategory;
  DateTime? _startDate;
  DateTime? _endDate;
  double? _minAmount;
  double? _maxAmount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    
    // Construire les paramètres de filtre
    Map<String, dynamic> params = {};
    if (_selectedType != null) params['type'] = _selectedType;
    if (_selectedCategory != null) params['category'] = _selectedCategory;
    if (_startDate != null) params['start_date'] = _startDate!.toIso8601String().split('T').first;
    if (_endDate != null) params['end_date'] = _endDate!.toIso8601String().split('T').first;
    if (_minAmount != null) params['min_amount'] = _minAmount;
    if (_maxAmount != null) params['max_amount'] = _maxAmount;
    
    final result = await _api.get('/transactions${params.isNotEmpty ? '?${Uri(queryParameters: params).query}' : ''}');
    
    if (mounted) {
      setState(() {
        _loading = false;
        if (result is Map && result.containsKey('data')) {
          _transactions = result['data'] as List;
        } else if (result is List) {
          _transactions = result;
        } else {
          _error = result?['message'] ?? 'Erreur';
        }
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredTransactions = _transactions.where((t) {
        // Filtre par recherche
        if (_searchQuery.isNotEmpty) {
          final description = (t['description'] ?? '').toLowerCase();
          final category = (t['category']?['name'] ?? '').toLowerCase();
          if (!description.contains(_searchQuery.toLowerCase()) && 
              !category.contains(_searchQuery.toLowerCase())) {
            return false;
          }
        }

        // Filtre par type
        if (_selectedType != null && t['type'] != _selectedType) {
          return false;
        }

        // Filtre par catégorie
        if (_selectedCategory != null && t['category']?['name'] != _selectedCategory) {
          return false;
        }

        // Filtre par date
        if (_startDate != null) {
          final txDate = DateTime.tryParse(t['transaction_date'] ?? '');
          if (txDate != null && txDate.isBefore(_startDate!)) {
            return false;
          }
        }
        if (_endDate != null) {
          final txDate = DateTime.tryParse(t['transaction_date'] ?? '');
          if (txDate != null && txDate.isAfter(_endDate!)) {
            return false;
          }
        }

        // Filtre par montant
        if (_minAmount != null && (t['amount'] ?? 0) < _minAmount!) {
          return false;
        }
        if (_maxAmount != null && (t['amount'] ?? 0) > _maxAmount!) {
          return false;
        }

        return true;
      }).toList();
    });
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _selectedType = null;
      _selectedCategory = null;
      _startDate = null;
      _endDate = null;
      _minAmount = null;
      _maxAmount = null;
    });
    _applyFilters();
  }

  Future<void> _delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: const Text('Cette transaction sera définitivement supprimée.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: AppTheme.error), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirm != true) return;

    await _api.delete('/transactions/$id');
    
    // Notification de suppression
    await NotificationService().showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Transaction supprimée',
      body: 'La transaction a été supprimée avec succès',
    );
    
    _load();
  }

  String _fmt(dynamic v) {
    final n = (v ?? 0).toDouble();
    return NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF ', decimalDigits: 0).format(n);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _tooltipKey.currentState?.showTooltip(),
            tooltip: 'Aide',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          if (_searchQuery.isNotEmpty || _selectedType != null || _selectedCategory != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _resetFilters,
              tooltip: 'Réinitialiser les filtres',
            ),
        ],
      ),
      body: OnboardingTooltip(
        key: _tooltipKey,
        screenName: 'transactions',
        title: 'Vos Transactions',
        description: 'Gérez toutes vos transactions ici : revenus, dépenses, et filtres.',
        additionalTips: [
          TooltipItem(
            icon: Icons.search,
            title: 'Recherche',
            description: 'Tapez pour rechercher une transaction par description ou catégorie',
          ),
          TooltipItem(
            icon: Icons.filter_list,
            title: 'Filtres',
            description: 'Filtrez par type, catégorie, date ou montant',
          ),
          TooltipItem(
            icon: Icons.swipe,
            title: 'Actions Rapides',
            description: 'Swipe gauche pour modifier, swipe droit pour supprimer',
          ),
          TooltipItem(
            icon: Icons.add,
            title: 'Ajouter',
            description: 'Utilisez le bouton + pour ajouter une nouvelle transaction',
          ),
        ],
        child: Column(
          children: [
            // Barre de recherche
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() => _searchQuery = '');
                            _applyFilters();
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  _searchQuery = value;
                  _applyFilters();
                },
              ),
            ),
            // Chips de filtres actifs
            if (_selectedType != null || _selectedCategory != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (_selectedType != null)
                      Chip(
                        label: Text(_selectedType == 'income' ? 'Revenus' : 'Dépenses'),
                        onDeleted: () {
                          setState(() => _selectedType = null);
                          _applyFilters();
                        },
                      ),
                    if (_selectedCategory != null)
                      Chip(
                        label: Text(_selectedCategory!),
                        onDeleted: () {
                          setState(() => _selectedCategory = null);
                          _applyFilters();
                        },
                      ),
                  ],
                ),
              ),
          // Liste des transactions
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _error != null
                        ? ListView(
                            children: [
                              const SizedBox(height: 100),
                              Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                              const SizedBox(height: 12),
                              Center(child: Text(_error!, style: const TextStyle(color: AppTheme.error))),
                              const SizedBox(height: 16),
                              Center(child: ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Réessayer'))),
                            ],
                          )
                        : _filteredTransactions.isEmpty
                            ? ListView(
                                children: [
                                  const SizedBox(height: 80),
                                  Icon(Icons.receipt_long_outlined, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                                  const SizedBox(height: 16),
                                  Center(child: Text('Aucune transaction trouvée', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                                  const SizedBox(height: 8),
                                  Center(child: Text('Ajoutez votre première transaction avec le bouton +', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                                ],
                              )
                            : ListView.separated(
                                itemCount: _filteredTransactions.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final t = _filteredTransactions[i];
                                  final income = t['type'] == 'income';
                                  return Dismissible(
                                    key: Key(t['id'].toString()),
                                    background: Container(
                                      color: AppTheme.error,
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      child: const Icon(Icons.delete, color: AppTheme.onError),
                                    ),
                                    secondaryBackground: Container(
                                      color: AppTheme.primary,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.only(left: 20),
                                      child: const Icon(Icons.edit, color: AppTheme.onPrimary),
                                    ),
                                    confirmDismiss: (direction) async {
                                      if (direction == DismissDirection.endToStart) {
                                        // Swipe to delete
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Supprimer ?'),
                                            content: const Text('Cette transaction sera définitivement supprimée.'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                                              TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: AppTheme.error), child: const Text('Supprimer')),
                                            ],
                                          ),
                                        );
                                        return confirm ?? false;
                                      }
                                      return false;
                                    },
                                    onDismissed: (direction) async {
                                      if (direction == DismissDirection.endToStart) {
                                        await _delete(t['id']);
                                      } else if (direction == DismissDirection.startToEnd) {
                                        // Swipe to edit
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => TransactionFormScreen(transaction: t)),
                                        );
                                        _load();
                                      }
                                    },
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: income ? AppTheme.primary.withValues(alpha: 0.12) : AppTheme.error.withValues(alpha: 0.12),
                                        child: Icon(income ? Icons.arrow_upward : Icons.arrow_downward,
                                            color: income ? AppTheme.primary : AppTheme.error, size: 18),
                                      ),
                                      title: Text(t['description'] ?? 'Transaction'),
                                      subtitle: Text('${t['category']?['name'] ?? 'Sans catégorie'}  •  ${t['transaction_date'] ?? 'Sans date'}'),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${income ? '+' : '-'}${_fmt(t['amount']).replaceAll('XOF ', '')}',
                                            style: TextStyle(
                                              color: income ? AppTheme.primary : AppTheme.error,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                      ),
                                      onTap: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => TransactionFormScreen(transaction: t)),
                                        );
                                        _load();
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                  ),
        ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionFormScreen()));
          _load();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filtres avancés'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Type', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String?>(
                      title: const Text('Tous'),
                      value: null,
                      groupValue: _selectedType,
                      onChanged: (value) {
                        setState(() => _selectedType = value);
                        _applyFilters();
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String?>(
                      title: const Text('Revenus'),
                      value: 'income',
                      groupValue: _selectedType,
                      onChanged: (value) {
                        setState(() => _selectedType = value);
                        _applyFilters();
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String?>(
                      title: const Text('Dépenses'),
                      value: 'expense',
                      groupValue: _selectedType,
                      onChanged: (value) {
                        setState(() => _selectedType = value);
                        _applyFilters();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Date de début', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _startDate = date);
                    _applyFilters();
                  }
                },
                label: Text(_startDate != null 
                    ? DateFormat('dd/MM/yyyy').format(_startDate!) 
                    : 'Sélectionner'),
              ),
              const SizedBox(height: 16),
              Text('Date de fin', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _endDate = date);
                    _applyFilters();
                  }
                },
                label: Text(_endDate != null 
                    ? DateFormat('dd/MM/yyyy').format(_endDate!) 
                    : 'Sélectionner'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetFilters();
            },
            child: const Text('Réinitialiser'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}
