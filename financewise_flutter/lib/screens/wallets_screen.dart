import 'package:flutter/material.dart';
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
      total += (w['balance'] ?? 0).toDouble();
    }
    return total;
  }

  void _showWalletDetail(Map<dynamic, dynamic> w) {
    final balance = (w['balance'] ?? 0).toDouble();
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            // Mini carte
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _fmt(balance),
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(type, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _walletDetailRow(Icons.category_outlined, 'Type', type),
            _walletDetailRow(Icons.calendar_today_outlined, 'Créé le', formattedDate),
            _walletDetailRow(
              Icons.trending_up,
              'Solde',
              _fmt(balance),
              valueColor: balance >= 0 ? AppTheme.primary : AppTheme.error,
            ),
            const SizedBox(height: 24),
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
                const SizedBox(width: 12),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          const Spacer(),
          Text(value, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: valueColor)),
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
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _wallets.length,
                            itemBuilder: (_, i) {
                              final w = _wallets[i];
                              final balance = (w['balance'] ?? 0).toDouble();
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
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: gradient,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: [
                                        BoxShadow(color: gradient[0].withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6)),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header : icône + nom + type
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Icon(icon, color: Colors.white, size: 18),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  name,
                                                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                type,
                                                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 18),
                                        // Solde
                                        const Text('Solde', style: TextStyle(color: Colors.white60, fontSize: 11)),
                                        const SizedBox(height: 2),
                                        Text(
                                          _fmt(balance),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        // Indicateur bas
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  balance >= 0 ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                                                  color: Colors.white60,
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  balance >= 0 ? 'Solde positif' : 'Solde négatif',
                                                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                                                ),
                                              ],
                                            ),
                                            const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
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
