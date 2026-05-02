import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
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
          _playAlertSoundForNewAlerts();
        });
      } else if (result is List) {
        setState(() {
          _alerts = result;
          _loading = false;
          _playAlertSoundForNewAlerts();
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

  int get _unreadCount => _alerts.where((a) => !(a['is_read'] ?? false)).length;

  void _playAlertSoundForNewAlerts() {
    // Importer NotificationService
    final notificationService = NotificationService();
    
    // Jouer une notification pour les alertes danger ou warning non lues
    final importantAlerts = _alerts.where((a) => 
      a['is_read'] == false && 
      (a['severity'] == 'danger' || a['severity'] == 'warning')
    ).toList();
    
    if (importantAlerts.isNotEmpty) {
      notificationService.showAlert(
        title: 'Alerte importante',
        message: 'Vous avez ${importantAlerts.length} alerte${importantAlerts.length > 1 ? 's' : ''} importante${importantAlerts.length > 1 ? 's' : ''}',
        severity: importantAlerts.any((a) => a['severity'] == 'danger') ? 'danger' : 'warning',
      );
    }
  }

  void _showAlertDetail(Map<dynamic, dynamic> alert) {
    final type = alert['type'] ?? 'info';
    final title = alert['title'] ?? 'Alerte';
    final message = alert['message'] ?? '';
    final isRead = alert['is_read'] ?? false;
    final color = _getAlertColor(type);
    final icon = _getAlertIcon(type);
    final createdAt = alert['created_at'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
            const Gap(24),
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
                      Expanded(
                        child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(message, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  if (createdAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _formatDate(createdAt),
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            const Gap(20),
            _detailRow(Icons.info_outline, 'Type', type.toUpperCase(), valueColor: color),
            _detailRow(Icons.visibility, 'Statut', isRead ? 'Lu' : 'Non lu', valueColor: isRead ? null : AppTheme.primary),
            if (!isRead) ...[
              const Gap(24),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _markAsRead(alert['id']);
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Marquer comme lu'),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _detailRow(IconData icon, String label, String value, {Color? valueColor}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: cs.onSurfaceVariant),
          ),
          const Gap(12),
          Text(label, style: GoogleFonts.inter(color: cs.onSurfaceVariant, fontSize: 13)),
          const Spacer(),
          Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: valueColor)),
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
            const Text('Alertes'),
            if (!_loading && _alerts.isNotEmpty && _unreadCount > 0)
              Text(
                '$_unreadCount non lue${_unreadCount > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          if (_unreadCount > 0)
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
                      const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                      const SizedBox(height: 12),
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
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Vous serez notifié ici des alertes budget et de revenu',
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
                          final color = _getAlertColor(type);
                          final icon = _getAlertIcon(type);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Dismissible(
                              key: Key(alert['id'].toString()),
                              direction: isRead ? DismissDirection.none : DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.check, color: Colors.white, size: 22),
                              ),
                              onDismissed: (_) => _markAsRead(alert['id']),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isRead ? Colors.white : color.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(18),
                                  border: isRead ? null : Border.all(color: color.withValues(alpha: 0.2), width: 1),
                                  boxShadow: AppTheme.softShadow,
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(18),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => _showAlertDetail(alert),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: color.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: Icon(icon, color: color, size: 22),
                                          ),
                                          const Gap(14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  alert['title'] ?? 'Alerte',
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const Gap(4),
                                                Text(
                                                  alert['message'] ?? '',
                                                  style: GoogleFonts.inter(
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (!isRead) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(width: 12),
                                        Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outlineVariant, size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      ),
                    ),
    );
  }
}
