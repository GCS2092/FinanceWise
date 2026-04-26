import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final _api = ApiService();
  List<dynamic> _recommendations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _api.get('/recommendations');
    if (mounted) {
      setState(() {
        _loading = false;
        if (result is Map && result.containsKey('data')) {
          _recommendations = result['data'] as List;
        } else if (result is List) {
          _recommendations = result;
        } else {
          _error = result?['message'] ?? 'Erreur';
        }
      });
    }
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'alert':
        return AppTheme.error;
      case 'warning':
        return Colors.orange;
      case 'suggestion':
        return AppTheme.tertiary;
      case 'info':
        return AppTheme.onSurfaceVariant;
      default:
        return AppTheme.tertiary;
    }
  }

  IconData _getTypeIcon(String? type) {
    switch (type) {
      case 'alert':
        return Icons.warning;
      case 'warning':
        return Icons.report_problem;
      case 'suggestion':
        return Icons.lightbulb;
      case 'info':
        return Icons.info;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommandations financières'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _error != null
                  ? ListView(
                      children: [
                        const SizedBox(height: 100),
                        const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                        const SizedBox(height: 12),
                        Center(child: Text(_error!, style: const TextStyle(color: AppTheme.error))),
                      ],
                    )
                  : _recommendations.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 100),
                            Icon(Icons.lightbulb_outline, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                            const SizedBox(height: 16),
                            Center(child: Text('Aucune recommandation pour le moment', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                            const SizedBox(height: 8),
                            Center(child: Text('Continuez à utiliser l\'app pour recevoir des conseils', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _recommendations.length,
                          itemBuilder: (_, i) {
                            final recommendation = _recommendations[i];
                            final type = recommendation['type'] ?? 'info';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getTypeColor(type).withValues(alpha: 0.15),
                                  child: Icon(
                                    _getTypeIcon(type),
                                    color: _getTypeColor(type),
                                  ),
                                ),
                                title: Text(
                                  recommendation['message'] ?? 'Recommandation',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: recommendation['category'] != null
                                    ? Text('Catégorie: ${recommendation['category']}')
                                    : null,
                              ),
                            );
                          },
                        ),
            ),
    );
  }
}
