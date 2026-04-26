import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final d = await _api.get('/dashboard');
    if (mounted && d is Map) {
      setState(() {
        _stats = d as Map<String, dynamic>;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    child: Icon(Icons.person, size: 48, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      user?.name ?? 'Utilisateur',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  Center(
                    child: Text(
                      user?.email ?? '',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Statistiques
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet, color: Colors.green),
                    title: const Text('Solde total'),
                    trailing: Text(
                      '${_stats?['balance'] ?? 0} XOF',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.trending_up, color: Colors.green),
                    title: const Text('Revenus (mois)'),
                    trailing: Text('${_stats?['monthly_income'] ?? 0} XOF'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.trending_down, color: Colors.red),
                    title: const Text('Dépenses (mois)'),
                    trailing: Text('${_stats?['monthly_expense'] ?? 0} XOF'),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Actions
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Déconnexion'),
                          content: const Text('Es-tu sûr de vouloir te déconnecter ?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Déconnexion')),
                          ],
                        ),
                      );
                      if (confirm == true && mounted) {
                        await context.read<AuthProvider>().logout();
                      }
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
