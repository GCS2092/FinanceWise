import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catégories'),
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
                          Text('Aucune catégorie', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final c = _categories[i];
                        final isSystem = c['is_system'] ?? false;
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isSystem
                                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                                  : AppTheme.primary.withValues(alpha: 0.12),
                              child: Icon(Icons.category, color: isSystem ? Theme.of(context).colorScheme.onSurfaceVariant : AppTheme.primary, size: 20),
                            ),
                            title: Text(c['name'] ?? ''),
                            subtitle: Text('${c['type']?.toString().toUpperCase() ?? ''} ${isSystem ? '• Système' : '• Personnalisée'}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isSystem)
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => CategoryFormScreen(category: c)),
                                      );
                                      if (result == true) _loadCategories();
                                    },
                                  ),
                                if (!isSystem)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.error),
                                    onPressed: () => _deleteCategory(c['id']),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
