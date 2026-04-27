import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/onboarding_tooltip.dart';
import '../theme.dart';
import '../widgets/skeleton_loader.dart';
import 'settings_screen.dart';
import 'export_screen.dart';
import 'statistics_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _stats;
  bool _loading = true;
  final GlobalKey<OnboardingTooltipState> _tooltipKey = GlobalKey<OnboardingTooltipState>();

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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mon compte', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.normal)),
            const SizedBox(height: 2),
            Text(user?.name ?? 'Utilisateur', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _tooltipKey.currentState?.showTooltip(),
            tooltip: 'Aide',
          ),
        ],
      ),
      body: OnboardingTooltip(
        key: _tooltipKey,
        screenName: 'profile',
        title: 'Votre Profil',
        description: 'Gérez vos informations personnelles et voyez vos statistiques.',
        additionalTips: [
          TooltipItem(
            icon: Icons.person,
            title: 'Informations',
            description: 'Vos nom et email enregistrés',
          ),
          TooltipItem(
            icon: Icons.account_balance_wallet,
            title: 'Statistiques',
            description: 'Vue d\'ensemble de vos finances',
          ),
          TooltipItem(
            icon: Icons.settings,
            title: 'Paramètres',
            description: 'Accédez aux paramètres de l\'application',
          ),
          TooltipItem(
            icon: Icons.logout,
            title: 'Déconnexion',
            description: 'Déconnectez-vous de votre compte',
          ),
        ],
        child: _loading
            ? const ListSkeleton(itemCount: 4)
            : RefreshIndicator(
                onRefresh: _loadStats,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Avatar with gradient
                    Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppTheme.primary, Color(0xFF004D3E)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(user?.name ?? 'U'),
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        user?.name ?? 'Utilisateur',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        user?.email ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Statistiques
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Résumé financier', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 16),
                            _buildStatRow(
                              icon: Icons.account_balance_wallet,
                              color: AppTheme.primary,
                              label: 'Solde total',
                              value: _formatAmount(_stats?['balance']),
                              valueColor: (_stats?['balance'] ?? 0) >= 0 ? AppTheme.primary : AppTheme.error,
                            ),
                            const Divider(height: 24),
                            _buildStatRow(
                              icon: Icons.trending_up,
                              color: AppTheme.primary,
                              label: 'Revenus du mois',
                              value: _formatAmount(_stats?['monthly_income']),
                              valueColor: AppTheme.primary,
                            ),
                            const Divider(height: 24),
                            _buildStatRow(
                              icon: Icons.trending_down,
                              color: AppTheme.error,
                              label: 'Dépenses du mois',
                              value: _formatAmount(_stats?['monthly_expense']),
                              valueColor: AppTheme.error,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick actions
                    Text('Actions rapides', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickAction(
                            icon: Icons.bar_chart,
                            label: 'Statistiques',
                            color: AppTheme.primary,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatisticsScreen())),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickAction(
                            icon: Icons.file_download_outlined,
                            label: 'Exporter',
                            color: AppTheme.tertiary,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExportScreen())),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickAction(
                            icon: Icons.settings,
                            label: 'Paramètres',
                            color: AppTheme.onSurfaceVariant,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                  // Logout
                  Card(
                    color: AppTheme.error.withValues(alpha: 0.06),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.logout, color: AppTheme.error, size: 20),
                      ),
                      title: const Text(
                        'Déconnexion',
                        style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: AppTheme.error),
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Déconnexion'),
                            content: const Text('Es-tu sûr de vouloir te déconnecter ?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                                child: const Text('Déconnexion'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && mounted) {
                          await context.read<AuthProvider>().logout();
                        }
                      },
                    ),
                  ),
                ],
              ),
          ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  String _formatAmount(dynamic value) => AppTheme.formatCurrency(value);

  Widget _buildStatRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
