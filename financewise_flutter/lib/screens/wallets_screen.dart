import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/onboarding_tooltip.dart';
import '../theme.dart';
import '../widgets/skeleton_loader.dart';
import 'wallet_form_screen.dart';

class WalletsScreen extends StatefulWidget {
  const WalletsScreen({super.key});

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  final _api = ApiService();
  List<dynamic> _wallets = [];
  bool _loading = true;
  String? _error;
  final GlobalKey<OnboardingTooltipState> _tooltipKey = GlobalKey<OnboardingTooltipState>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _api.get('/wallets');
    if (mounted) {
      setState(() {
        _loading = false;
        if (result is Map && result.containsKey('data')) {
          _wallets = result['data'] as List;
        } else if (result is List) {
          _wallets = result;
        } else {
          _error = result?['message'] ?? 'Erreur';
        }
      });
    }
  }

  Future<void> _delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: const Text('Le wallet et ses transactions seront supprimés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final result = await _api.delete('/wallets/$id');

    if (result is Map && result['message'] != null && (result['_conflict'] == true || result['_rate_limited'] == true)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return;
    }
    
    // Notification de suppression
    await NotificationService().showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Wallet supprimé',
      body: 'Le wallet a été supprimé avec succès',
    );
    
    _load();
  }

  String _fmt(dynamic v) => AppTheme.formatCurrency(v);

  // Gradient et icône selon le type de wallet
  List<Color> _walletGradient(String? type) {
    switch (type?.toLowerCase()) {
      case 'wave':
        return [const Color(0xFF1A237E), const Color(0xFF283593), const Color(0xFF3949AB)];
      case 'orange money':
        return [const Color(0xFFE65100), const Color(0xFFF57C00), const Color(0xFFFF9800)];
      case 'banque':
      case 'bank':
        return [const Color(0xFF004D40), const Color(0xFF00695C), const Color(0xFF00897B)];
      case 'espèces':
      case 'cash':
        return [const Color(0xFF33691E), const Color(0xFF558B2F), const Color(0xFF689F38)];
      default:
        return [const Color(0xFF37474F), const Color(0xFF546E7A), const Color(0xFF78909C)];
    }
  }

  IconData _walletIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'wave':
        return Icons.waves;
      case 'orange money':
        return Icons.phone_android;
      case 'banque':
      case 'bank':
        return Icons.account_balance;
      case 'espèces':
      case 'cash':
        return Icons.payments;
      default:
        return Icons.account_balance_wallet;
    }
  }

  double get _totalBalance {
    double total = 0;
    for (final w in _wallets) {
      total += double.tryParse((w['balance'] ?? 0).toString()) ?? 0;
    }
    return total;
  }

  void _showWalletDetail(Map<dynamic, dynamic> w) {
    final balance = double.tryParse((w['balance'] ?? 0).toString()) ?? 0;
    final type = w['type']?.toString() ?? 'Autre';
    final name = w['name']?.toString() ?? 'Portefeuille';
    final gradient = _walletGradient(type);
    final icon = _walletIcon(type);
    final createdAt = w['created_at']?.toString() ?? '';
    final formattedDate = createdAt.length >= 10
        ? '${createdAt.substring(8, 10)}/${createdAt.substring(5, 7)}/${createdAt.substring(0, 4)}'
        : '—';

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
            const Gap(20),
            // Mini carte
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: gradient[0].withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                        child: Icon(icon, color: Colors.white, size: 20),
                      ),
                      const Gap(10),
                      Text(name, style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const Gap(20),
                  Text(
                    _fmt(balance),
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                  const Gap(4),
                  Text(type, style: GoogleFonts.inter(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
            const Gap(24),
            _walletDetailRow(Icons.category_outlined, 'Type', type),
            _walletDetailRow(Icons.calendar_today_outlined, 'Créé le', formattedDate),
            _walletDetailRow(
              Icons.trending_up_rounded,
              'Solde',
              _fmt(balance),
              valueColor: balance >= 0 ? AppTheme.success : AppTheme.error,
            ),
            const Gap(28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => WalletFormScreen(wallet: Map<String, dynamic>.from(w)))).then((_) => _load());
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Modifier'),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _delete(w['id']);
                    },
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Supprimer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _walletDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
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
          Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: valueColor ?? cs.onSurface)),
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
            const Text('Portefeuilles'),
            if (!_loading && _wallets.isNotEmpty)
              Text(
                '${_wallets.length} compte${_wallets.length > 1 ? 's' : ''} • ${_fmt(_totalBalance)}',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.normal),
              ),
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
        screenName: 'wallets',
        title: 'Vos Portefeuilles',
        description: 'Gérez tous vos comptes : Wave, Orange Money, Banque, Espèces, etc.',
        additionalTips: [
          TooltipItem(
            icon: Icons.account_balance_wallet,
            title: 'Solde',
            description: 'Le solde actuel de chaque portefeuille',
          ),
          TooltipItem(
            icon: Icons.add,
            title: 'Ajouter',
            description: 'Créez un nouveau portefeuille avec le bouton +',
          ),
          TooltipItem(
            icon: Icons.swipe,
            title: 'Détails',
            description: 'Tapez sur un portefeuille pour voir les détails',
          ),
        ],
        child: _loading
            ? const ListSkeleton(itemCount: 3)
            : RefreshIndicator(
                onRefresh: _load,
                child: _error != null
                    ? ListView(
                        children: [
                          const SizedBox(height: 100),
                          Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                          const SizedBox(height: 12),
                          Center(child: Text(_error!, style: const TextStyle(color: AppTheme.error))),
                          const SizedBox(height: 16),
                          Center(child: ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Réessayer'))),
                        ],
                      )
                    : _wallets.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 80),
                              Icon(Icons.account_balance_wallet_outlined, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                              const SizedBox(height: 16),
                              Center(child: Text('Aucun portefeuille', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500))),
                              const SizedBox(height: 8),
                              Center(child: Text('Ajoutez Wave, Orange Money, Banque...', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                              const SizedBox(height: 24),
                              Center(
                                child: FilledButton.icon(
                                  onPressed: () async {
                                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletFormScreen()));
                                    _load();
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Ajouter un portefeuille'),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _wallets.length,
                            itemBuilder: (_, i) {
                              final w = _wallets[i];
                              final balance = double.tryParse((w['balance'] ?? 0).toString()) ?? 0;
                              final type = w['type']?.toString() ?? 'Autre';
                              final name = w['name']?.toString() ?? 'Portefeuille';
                              final gradient = _walletGradient(type);
                              final icon = _walletIcon(type);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: GestureDetector(
                                  onTap: () => _showWalletDetail(w),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: gradient,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(color: gradient[0].withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 8)),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Icon(icon, color: Colors.white, size: 18),
                                                ),
                                                const Gap(10),
                                                Text(name, style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(type, style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
                                            ),
                                          ],
                                        ),
                                        const Gap(20),
                                        Text('Solde', style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                                        const Gap(4),
                                        Text(
                                          _fmt(balance),
                                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
                                        ),
                                        const Gap(14),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  balance >= 0 ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                                                  color: Colors.white54,
                                                  size: 14,
                                                ),
                                                const Gap(6),
                                                Text(
                                                  balance >= 0 ? 'Solde positif' : 'Solde négatif',
                                                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                              child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 12),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                                  .animate()
                                  .fadeIn(delay: (100 * i).ms, duration: 400.ms)
                                  .slideY(begin: 0.1, end: 0, delay: (100 * i).ms, duration: 400.ms);
                            },
                          ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletFormScreen()));
          _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Portefeuille'),
      ),
    );
  }
}
