import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'suggestion':
        return Colors.blue;
      case 'info':
        return Colors.grey;
      default:
        return Colors.blue;
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
                      children: [SizedBox(height: 200), Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))],
                    )
                  : _recommendations.isEmpty
                      ? ListView(
                          children: const [SizedBox(height: 200), Center(child: Text('Aucune recommandation pour le moment', style: TextStyle(color: Colors.grey)))],
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
