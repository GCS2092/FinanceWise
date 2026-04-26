import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.get('/dashboard');
      final alerts = result is Map ? (result['alerts'] as List<dynamic>? ?? []) : [];
      setState(() {
        _notifications = alerts;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _notifications.isEmpty
                  ? const Center(child: Text('Aucune notification', style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final alert = _notifications[i];
                        final type = alert['type'] ?? 'warning';
                        final color = type == 'warning' ? Colors.orange : Colors.red;
                        return Card(
                          color: color.withValues(alpha: 0.1),
                          child: ListTile(
                            leading: Icon(Icons.warning, color: color),
                            title: Text(alert['message'] ?? '', style: TextStyle(color: color)),
                            subtitle: Text(alert['created_at'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ),
                        );
                      },
                    ),
    );
  }
}
