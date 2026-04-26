import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/sms_native_service.dart';
import '../theme.dart';
import 'dashboard_screen.dart';
import 'transactions_screen.dart';
import 'wallets_screen.dart';
import 'budgets_screen.dart';
import 'categories_screen.dart';
import 'sms_parser_screen.dart';
import 'notifications_screen.dart';
import 'export_screen.dart';
import 'statistics_screen.dart';
import 'settings_screen.dart';
import 'financial_goals_screen.dart';
import 'payment_reminders_screen.dart';
import 'recommendations_screen.dart';
import 'profile_screen.dart';
import 'alerts_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final SmsNativeService _smsService = SmsNativeService();

  final List<Widget> _pages = const [
    DashboardScreen(),
    TransactionsScreen(),
    WalletsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Initialiser l'écoute SMS après un court délai
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _smsService.initialize(context);
    });
  }

  @override
  void dispose() {
    _smsService.stopListening();
    super.dispose();
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Plus d\'options',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  _OptionTile(
                    icon: Icons.bar_chart,
                    color: AppTheme.primary,
                    title: 'Statistiques',
                    subtitle: 'Graphiques et analyses financières',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StatisticsScreen()));
                    },
                  ),
                  _OptionTile(
                    icon: Icons.notifications_active,
                    color: Colors.orange,
                    title: 'Alertes',
                    subtitle: 'Alertes budget et revenus',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsScreen()));
                    },
                  ),
                  _OptionTile(
                    icon: Icons.lightbulb,
                    color: AppTheme.tertiary,
                    title: 'Recommandations IA',
                    subtitle: 'Conseils financiers personnalisés',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const RecommendationsScreen()));
                    },
                  ),
                  _OptionTile(
                    icon: Icons.flag,
                    color: AppTheme.primary,
                    title: 'Objectifs financiers',
                    subtitle: 'Suivez vos objectifs d\'épargne',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancialGoalsScreen()));
                    },
                  ),
                  _OptionTile(
                    icon: Icons.alarm,
                    color: AppTheme.error,
                    title: 'Rappels de paiement',
                    subtitle: 'Ne manquez aucun paiement',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentRemindersScreen()));
                    },
                  ),
                  _OptionTile(
                    icon: Icons.category,
                    color: AppTheme.secondary,
                    title: 'Catégories',
                    subtitle: 'Gérer vos catégories',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen()));
                    },
                  ),
                  _OptionTile(
                    icon: Icons.pie_chart,
                    color: AppTheme.secondary,
                    title: 'Budgets',
                    subtitle: 'Contrôlez vos dépenses',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetsScreen()));
                    },
                  ),
                  _OptionTile(
                    icon: Icons.notifications_outlined,
                    color: Colors.orange,
                    title: 'Notifications',
                    subtitle: 'Historique des notifications',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                    },
                  ),
                  _OptionTile(
                    icon: Icons.file_download_outlined,
                    color: AppTheme.tertiary,
                    title: 'Exporter',
                    subtitle: 'Exporter vos données financières',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ExportScreen()));
                    },
                  ),
                  _OptionTile(
                    icon: Icons.sms_outlined,
                    color: AppTheme.primary,
                    title: 'Parser SMS',
                    subtitle: 'Détecter les transactions depuis SMS',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SmsParserScreen()));
                    },
                  ),
                  _OptionTile(
                    icon: Icons.settings,
                    color: AppTheme.onSurfaceVariant,
                    title: 'Paramètres',
                    subtitle: 'Configuration de l\'app',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _OptionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outlineVariant),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FinanceWise'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primary, Color(0xFF004D3E)],
                ),
              ),
              accountName: Text(user?.name ?? 'Utilisateur'),
              accountEmail: Text(user?.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(
                  (user?.name ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: _selectedIndex == 0,
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Transactions'),
              selected: _selectedIndex == 1,
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text('Wallets'),
              selected: _selectedIndex == 2,
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profil'),
              selected: _selectedIndex == 3,
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(3);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Paramètres'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.more_horiz),
              title: const Text('Plus d\'options'),
              onTap: () {
                Navigator.pop(context);
                _showMoreOptions(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: AppTheme.error),
              title: Text('Déconnexion', style: TextStyle(color: AppTheme.error)),
              onTap: () async {
                Navigator.pop(context);
                await context.read<AuthProvider>().logout();
              },
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_outlined),
            selectedIcon: Icon(Icons.swap_horiz),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Wallets',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }
}
