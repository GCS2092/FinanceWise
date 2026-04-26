import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _api = ApiService();
  List<dynamic> _alerts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _api.get('/alerts');
      if (result is Map && result['data'] is List) {
        setState(() {
          _alerts = result['data'];
          _loading = false;
        });
      } else if (result is List) {
        setState(() {
          _alerts = result;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Format de réponse invalide';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markAsRead(int alertId) async {
    try {
      await _api.post('/alerts/$alertId/mark-read', {});
      await _loadAlerts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _api.post('/alerts/mark-all-read', {});
      await _loadAlerts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Color _getAlertColor(String type) {
    switch (type) {
      case 'danger':
        return AppTheme.error;
      case 'warning':
        return Colors.orange;
      case 'success':
        return AppTheme.primary;
      case 'info':
        return AppTheme.tertiary;
      default:
        return AppTheme.onSurfaceVariant;
    }
  }

  IconData _getAlertIcon(String type) {
    switch (type) {
      case 'danger':
        return Icons.error;
      case 'warning':
        return Icons.warning;
      case 'success':
        return Icons.check_circle;
      case 'info':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertes'),
        actions: [
          if (_alerts.isNotEmpty)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, size: 20),
              label: const Text('Tout lire'),
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
                      Text(_error!, style: const TextStyle(color: AppTheme.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadAlerts, child: const Text('Réessayer')),
                    ],
                  ),
                )
              : _alerts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_none, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune alerte',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Vous serez noté ici des alertes budget et de revenu',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAlerts,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _alerts.length,
                        itemBuilder: (context, index) {
                          final alert = _alerts[index];
                          final type = alert['type'] ?? 'info';
                          final isRead = alert['is_read'] ?? false;

                          return Card(
                            color: isRead ? null : _getAlertColor(type).withValues(alpha: 0.1),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getAlertColor(type).withValues(alpha: 0.2),
                                child: Icon(
                                  _getAlertIcon(type),
                                  color: _getAlertColor(type),
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                alert['title'] ?? 'Alerte',
                                style: TextStyle(
                                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(alert['message'] ?? ''),
                              trailing: !isRead
                                  ? IconButton(
                                      icon: const Icon(Icons.check, size: 20),
                                      onPressed: () => _markAsRead(alert['id']),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
