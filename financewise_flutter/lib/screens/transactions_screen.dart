import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/onboarding_tooltip.dart';
import '../theme.dart';
import '../widgets/skeleton_loader.dart';
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
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _nextCursor;
  String? _error;
  final GlobalKey<OnboardingTooltipState> _tooltipKey = GlobalKey<OnboardingTooltipState>();
  final ScrollController _scrollController = ScrollController();
  
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
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  String _buildQueryString() {
    Map<String, String> params = {};
    if (_selectedType != null) params['type'] = _selectedType!;
    if (_selectedCategory != null) params['category'] = _selectedCategory!;
    if (_startDate != null) params['start_date'] = _startDate!.toIso8601String().split('T').first;
    if (_endDate != null) params['end_date'] = _endDate!.toIso8601String().split('T').first;
    if (_minAmount != null) params['min_amount'] = _minAmount.toString();
    if (_maxAmount != null) params['max_amount'] = _maxAmount.toString();
    return params.isNotEmpty ? '?${Uri(queryParameters: params).query}' : '';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _nextCursor = null;
      _hasMore = true;
      _transactions = [];
    });
    
    final result = await _api.get('/transactions${_buildQueryString()}');
    
    if (mounted) {
      setState(() {
        _loading = false;
        if (result is Map && result.containsKey('data')) {
          _transactions = result['data'] as List;
          _nextCursor = result['next_cursor']?.toString();
          _hasMore = _nextCursor != null;
        } else if (result is List) {
          _transactions = result;
          _hasMore = false;
        } else {
          _error = result?['message'] ?? 'Erreur';
        }
        _applyFilters();
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _nextCursor == null) return;
    
    setState(() => _loadingMore = true);
    
    final separator = _buildQueryString().isEmpty ? '?' : '&';
    final base = '/transactions${_buildQueryString()}';
    final url = '$base${separator}cursor=$_nextCursor';
    
    final result = await _api.get(url);
    
    if (mounted) {
      setState(() {
        _loadingMore = false;
        if (result is Map && result.containsKey('data')) {
          _transactions.addAll(result['data'] as List);
          _nextCursor = result['next_cursor']?.toString();
          _hasMore = _nextCursor != null;
        } else {
          _hasMore = false;
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

  String _fmt(dynamic v) => AppTheme.formatCurrency(v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Transactions'),
            if (!_loading)
              Text(
                '${_filteredTransactions.length} transaction${_filteredTransactions.length > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _tooltipKey.currentState?.showTooltip(),
            tooltip: 'Aide',
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: _showFilterDialog,
                tooltip: 'Filtres',
              ),
              if (_selectedType != null || _selectedCategory != null || _startDate != null || _endDate != null)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                  ),
                ),
            ],
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
                ? const ListSkeleton()
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
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                itemCount: _filteredTransactions.length + (_hasMore ? 1 : 0),
                                itemBuilder: (_, i) {
                                  if (i >= _filteredTransactions.length) {
                                    return Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Center(
                                        child: _loadingMore
                                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                                            : const SizedBox.shrink(),
                                      ),
                                    );
                                  }
                                  final t = _filteredTransactions[i];
                                  final income = t['type'] == 'income';
                                  final catName = t['category']?['name'] ?? 'Sans catégorie';
                                  final walletName = t['wallet']?['name'] ?? '';
                                  final date = t['transaction_date']?.toString() ?? '';
                                  final shortDate = date.length >= 10 ? '${date.substring(8, 10)}/${date.substring(5, 7)}/${date.substring(0, 4)}' : date;

                                  return Dismissible(
                                    key: Key(t['id'].toString()),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 24),
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.error,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
                                    ),
                                    confirmDismiss: (_) async {
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
                                      if (confirm == true) await _delete(t['id']);
                                      return false;
                                    },
                                    child: Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: () => _showTransactionDetail(t),
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 44, height: 44,
                                                decoration: BoxDecoration(
                                                  color: income ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.error.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Icon(income ? Icons.south_west : Icons.north_east, color: income ? AppTheme.primary : AppTheme.error, size: 20),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      t['description'] ?? 'Transaction',
                                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: Theme.of(context).colorScheme.secondaryContainer,
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(catName, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSecondaryContainer)),
                                                        ),
                                                        if (walletName.isNotEmpty) ...[
                                                          const SizedBox(width: 6),
                                                          Text('•', style: TextStyle(color: Theme.of(context).colorScheme.outlineVariant, fontSize: 10)),
                                                          const SizedBox(width: 6),
                                                          Text(walletName, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                                        ],
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    '${income ? '+' : '-'}${_fmt(t['amount'])}',
                                                    style: TextStyle(color: income ? AppTheme.primary : AppTheme.error, fontWeight: FontWeight.bold, fontSize: 14),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(shortDate, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
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

  void _showTransactionDetail(Map<dynamic, dynamic> t) {
    final income = t['type'] == 'income';
    final catName = t['category']?['name'] ?? 'Sans catégorie';
    final walletName = t['wallet']?['name'] ?? '';
    final date = t['transaction_date']?.toString() ?? '';
    final formattedDate = date.length >= 10 ? '${date.substring(8, 10)}/${date.substring(5, 7)}/${date.substring(0, 4)}' : date;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: income ? AppTheme.primary.withValues(alpha: 0.12) : AppTheme.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(income ? Icons.south_west : Icons.north_east, color: income ? AppTheme.primary : AppTheme.error, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              '${income ? '+' : '-'}${_fmt(t['amount'])}',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: income ? AppTheme.primary : AppTheme.error),
            ),
            const SizedBox(height: 4),
            Text(income ? 'Revenu' : 'Dépense', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 20),
            _detailRow(Icons.description_outlined, 'Description', t['description'] ?? '—'),
            _detailRow(Icons.category_outlined, 'Catégorie', catName),
            if (walletName.isNotEmpty) _detailRow(Icons.account_balance_wallet_outlined, 'Portefeuille', walletName),
            _detailRow(Icons.calendar_today_outlined, 'Date', formattedDate),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => TransactionFormScreen(transaction: Map<String, dynamic>.from(t))));
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Modifier'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _delete(t['id']);
                    },
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Supprimer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          const Spacer(),
          Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13), textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filtres', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () {
                      _resetFilters();
                      setSheetState(() {});
                    },
                    child: const Text('Réinitialiser'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Type', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _filterChip('Tous', _selectedType == null, () {
                    setState(() => _selectedType = null);
                    setSheetState(() {});
                    _applyFilters();
                  }),
                  const SizedBox(width: 8),
                  _filterChip('Revenus', _selectedType == 'income', () {
                    setState(() => _selectedType = 'income');
                    setSheetState(() {});
                    _applyFilters();
                  }),
                  const SizedBox(width: 8),
                  _filterChip('Dépenses', _selectedType == 'expense', () {
                    setState(() => _selectedType = 'expense');
                    setSheetState(() {});
                    _applyFilters();
                  }),
                ],
              ),
              const SizedBox(height: 16),
              Text('Période', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _startDate = date);
                          setSheetState(() {});
                          _applyFilters();
                        }
                      },
                      label: Text(_startDate != null ? DateFormat('dd/MM/yy').format(_startDate!) : 'Début', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _endDate = date);
                          setSheetState(() {});
                          _applyFilters();
                        }
                      },
                      label: Text(_endDate != null ? DateFormat('dd/MM/yy').format(_endDate!) : 'Fin', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Voir ${_filteredTransactions.length} résultat${_filteredTransactions.length > 1 ? 's' : ''}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
