import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/onboarding_tooltip.dart';
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
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirm != true) return;
    await _api.delete('/wallets/$id');
    
    // Notification de suppression
    await NotificationService().showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Wallet supprimé',
      body: 'Le wallet a été supprimé avec succès',
    );
    
    _load();
  }

  String _fmt(dynamic v) {
    final n = (v ?? 0).toDouble();
    return NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF ', decimalDigits: 0).format(n);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallets'),
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
            icon: Icons.edit,
            title: 'Modifier',
            description: 'Tap sur un wallet pour modifier ses informations',
          ),
          TooltipItem(
            icon: Icons.delete,
            title: 'Supprimer',
            description: 'Supprimez un wallet avec l\'icône poubelle',
          ),
        ],
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _error != null
                    ? ListView(children: [SizedBox(height: 200), Center(child: Text(_error!, style: TextStyle(color: Colors.red)))])
                    : _wallets.isEmpty
                        ? ListView(children: const [SizedBox(height: 200), Center(child: Text('Aucun wallet', style: TextStyle(color: Colors.grey)))])
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _wallets.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final w = _wallets[i];
                              final balance = (w['balance'] ?? 0).toDouble();
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: balance >= 0 ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                                    child: Icon(Icons.account_balance_wallet, color: balance >= 0 ? Colors.green : Colors.red, size: 20),
                                  ),
                                  title: Text(w['name'] ?? 'Wallet'),
                                  subtitle: Text('${w['type']?.toString().replaceAll('_', ' ').toUpperCase()} • ${w['currency'] ?? 'XOF'}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_fmt(balance), style: TextStyle(fontWeight: FontWeight.bold, color: balance >= 0 ? Colors.green : Colors.red)),
                                      IconButton(icon: const Icon(Icons.delete, color: Colors.grey, size: 20), onPressed: () => _delete(w['id'])),
                                    ],
                                  ),
                                  onTap: () async {
                                    await Navigator.push(context, MaterialPageRoute(builder: (_) => WalletFormScreen(wallet: w)));
                                    _load();
                                  },
                                ),
                              );
                            },
                          ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletFormScreen()));
          _load();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
