import 'package:flutter/material.dart';
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
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (innerCtx, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(innerCtx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Plus d\'options',
                style: Theme.of(innerCtx).textTheme.titleLarge?.copyWith(
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
                      Navigator.pop(sheetCtx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StatisticsScreen()));
                    },
                  ),
                  _OptionTile(
                    icon: Icons.notifications_active,
                    color: Colors.orange,
                    title: 'Alertes',
                    subtitle: 'Alertes budget et revenus',
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsScreen()));
                    },
                  ),
                  _OptionTile(
                    icon: Icons.lightbulb,
                    color: AppTheme.tertiary,
                    title: 'Recommandations IA',
                    subtitle: 'Conseils financiers personnalisés',
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const RecommendationsScreen()));
                    },
                  ),
                  _OptionTile(
                    icon: Icons.flag,
                    color: AppTheme.primary,
                    title: 'Objectifs financiers',
                    subtitle: 'Suivez vos objectifs d\'épargne',
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancialGoalsScreen()));
                    },
                  ),
                  _OptionTile(
                    icon: Icons.alarm,
                    color: AppTheme.error,
                    title: 'Rappels de paiement',
                    subtitle: 'Ne manquez aucun paiement',
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentRemindersScreen()));
                    },
                  ),
                  _OptionTile(
                    icon: Icons.category,
                    color: AppTheme.secondary,
                    title: 'Catégories',
                    subtitle: 'Gérer vos catégories',
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen()));
                    },
                  ),
                  _OptionTile(
                    icon: Icons.pie_chart,
                    color: AppTheme.secondary,
                    title: 'Budgets',
                    subtitle: 'Contrôlez vos dépenses',
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetsScreen()));
                    },
                  ),
                  _OptionTile(
                    icon: Icons.notifications_outlined,
                    color: Colors.orange,
                    title: 'Notifications',
                    subtitle: 'Historique des notifications',
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                    },
                  ),
                  _OptionTile(
                    icon: Icons.file_download_outlined,
                    color: AppTheme.tertiary,
                    title: 'Exporter',
                    subtitle: 'Exporter vos données financières',
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ExportScreen()));
                    },
                  ),
                  _OptionTile(
                    icon: Icons.sms_outlined,
                    color: AppTheme.primary,
                    title: 'Parser SMS',
                    subtitle: 'Détecter les transactions depuis SMS',
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SmsParserScreen()));
                    },
                  ),
                  _OptionTile(
                    icon: Icons.settings,
                    color: AppTheme.onSurfaceVariant,
                    title: 'Paramètres',
                    subtitle: 'Configuration de l\'app',
                    onTap: () {
                      Navigator.pop(sheetCtx);
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
    return Builder(
      builder: (tileCtx) => ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(tileCtx).colorScheme.onSurfaceVariant)),
        trailing: Icon(Icons.chevron_right, color: Theme.of(tileCtx).colorScheme.outlineVariant),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Plus',
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index == 4) {
      _showMoreOptions(context);
      return;
    }
    setState(() => _selectedIndex = index);
  }
}
