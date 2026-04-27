import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
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
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (innerCtx, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(innerCtx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const Gap(12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Gap(16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 20),
                    ),
                    const Gap(14),
                    Text('Plus d\'options', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Gap(12),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    _buildOptionTile(sheetCtx, Icons.bar_chart_rounded, AppTheme.primary, 'Statistiques', 'Graphiques et analyses', const StatisticsScreen()),
                    _buildOptionTile(sheetCtx, Icons.notifications_active_rounded, AppTheme.warning, 'Alertes', 'Alertes budget et revenus', const AlertsScreen()),
                    _buildOptionTile(sheetCtx, Icons.lightbulb_rounded, AppTheme.tertiary, 'Recommandations', 'Conseils personnalisés', const RecommendationsScreen()),
                    _buildOptionTile(sheetCtx, Icons.flag_rounded, AppTheme.success, 'Objectifs', 'Suivez vos objectifs', const FinancialGoalsScreen()),
                    _buildOptionTile(sheetCtx, Icons.alarm_rounded, AppTheme.error, 'Rappels', 'Ne manquez aucun paiement', const PaymentRemindersScreen()),
                    _buildOptionTile(sheetCtx, Icons.category_rounded, AppTheme.secondary, 'Catégories', 'Gérer vos catégories', const CategoriesScreen()),
                    _buildOptionTile(sheetCtx, Icons.pie_chart_rounded, AppTheme.primary, 'Budgets', 'Contrôlez vos dépenses', const BudgetsScreen()),
                    _buildOptionTile(sheetCtx, Icons.notifications_outlined, AppTheme.warning, 'Notifications', 'Historique', const NotificationsScreen()),
                    _buildOptionTile(sheetCtx, Icons.file_download_outlined, AppTheme.tertiary, 'Exporter', 'Exporter vos données', const ExportScreen()),
                    _buildOptionTile(sheetCtx, Icons.sms_outlined, AppTheme.primary, 'Parser SMS', 'Détecter les transactions', const SmsParserScreen()),
                    _buildOptionTile(sheetCtx, Icons.settings_rounded, AppTheme.outline, 'Paramètres', 'Configuration de l\'app', const SettingsScreen()),
                    const Gap(16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(BuildContext sheetCtx, IconData icon, Color color, String title, String subtitle, Widget screen) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: cs.onSurfaceVariant)),
        trailing: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: cs.onSurfaceVariant),
        ),
        onTap: () {
          Navigator.pop(sheetCtx);
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).navigationBarTheme.backgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.swap_horiz_outlined),
              selectedIcon: Icon(Icons.swap_horiz_rounded),
              label: 'Transactions',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Wallets',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Plus',
            ),
          ],
        ),
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
