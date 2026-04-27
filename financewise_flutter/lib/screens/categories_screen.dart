import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import 'category_form_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _categories = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.get('/categories');
      final data = result is Map ? (result['data'] ?? result) : result;
      setState(() {
        _categories = data is List ? data : [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _deleteCategory(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer'),
        content: const Text('Supprimer cette catégorie ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer', style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _api.delete('/categories/$id');
      
      // Notification de suppression
      await NotificationService().showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: 'Catégorie supprimée',
        body: 'La catégorie a été supprimée avec succès',
      );
      
      _loadCategories();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Catégorie supprimée')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  // Icône selon nom/type
  IconData _categoryIcon(String? name, String? type) {
    final n = name?.toLowerCase() ?? '';
    final t = type?.toLowerCase() ?? '';
    if (n.contains('aliment') || n.contains('food') || n.contains('nourriture')) return Icons.restaurant;
    if (n.contains('transport') || n.contains('voiture') || n.contains('car')) return Icons.directions_car;
    if (n.contains('logement') || n.contains('maison') || n.contains('house')) return Icons.home;
    if (n.contains('santé') || n.contains('health') || n.contains('medical')) return Icons.medical_services;
    if (n.contains('éducation') || n.contains('school') || n.contains('études')) return Icons.school;
    if (n.contains('shopping') || n.contains('achats') || n.contains('magasin')) return Icons.shopping_bag;
    if (n.contains('loisir') || n.contains('fun') || n.contains('divertissement')) return Icons.movie;
    if (n.contains('facture') || n.contains('utilities') || n.contains('eau') || n.contains('électricité')) return Icons.receipt_long;
    if (n.contains('salaire') || n.contains('revenu') || n.contains('income')) return Icons.attach_money;
    if (n.contains('épargne') || n.contains('saving')) return Icons.savings;
    return Icons.category;
  }

  Color _typeColor(String? type) {
    return type?.toLowerCase() == 'income' ? AppTheme.primary : AppTheme.error;
  }

  void _showCategoryDetail(Map<dynamic, dynamic> c) {
    final name = c['name'] ?? '';
    final type = c['type']?.toString().toUpperCase() ?? '';
    final isSystem = c['is_system'] ?? false;
    final icon = _categoryIcon(name, type);
    final color = _typeColor(type);

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
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: Colors.white70, size: 24),
                      const SizedBox(width: 12),
                      Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(type, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                  if (isSystem) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.lock, color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        const Text('Système', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            _detailRow(Icons.category_outlined, 'Nom', name),
            _detailRow(Icons.trending_up, 'Type', type, valueColor: color),
            _detailRow(Icons.info_outline, 'Statut', isSystem ? 'Système (non modifiable)' : 'Personnalisée'),
            if (!isSystem) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryFormScreen(category: Map<String, dynamic>.from(c)))).then((_) => _loadCategories());
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
                        _deleteCategory(c['id']);
                      },
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Supprimer'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          const Spacer(),
          Text(value, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: valueColor)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Catégories'),
            if (!_loading && _categories.isNotEmpty)
              Text(
                '${_categories.length} catégorie${_categories.length > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryFormScreen()));
              if (result == true) _loadCategories();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppTheme.error)),
                    ],
                  ),
                )
              : _categories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.category_outlined, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                          const SizedBox(height: 16),
                          Text('Aucune catégorie', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Text('Créez des catégories pour organiser vos transactions', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _categories.length,
                      itemBuilder: (_, i) {
                        final c = _categories[i];
                        final name = c['name'] ?? '';
                        final type = c['type']?.toString().toUpperCase() ?? '';
                        final isSystem = c['is_system'] ?? false;
                        final icon = _categoryIcon(name, type);
                        final color = _typeColor(type);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Dismissible(
                            key: Key(c['id'].toString()),
                            direction: isSystem ? DismissDirection.none : DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: AppTheme.error,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
                            ),
                            confirmDismiss: (_) async {
                              if (isSystem) return false;
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Supprimer ?'),
                                  content: const Text('Cette catégorie sera supprimée.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: AppTheme.error), child: const Text('Supprimer')),
                                  ],
                                ),
                              );
                              if (confirm == true) await _deleteCategory(c['id']);
                              return false;
                            },
                            child: Card(
                              margin: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => _showCategoryDetail(c),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(icon, color: color, size: 22),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: color.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(type, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                                                ),
                                                if (isSystem) ...[
                                                  const SizedBox(width: 6),
                                                  Icon(Icons.lock, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isSystem) ...[
                                        const SizedBox(width: 12),
                                        Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outlineVariant, size: 18),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryFormScreen()));
          if (result == true) _loadCategories();
        },
        icon: const Icon(Icons.add),
        label: const Text('Catégorie'),
      ),
    );
  }
}
