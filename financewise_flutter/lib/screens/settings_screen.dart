import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/auto_transaction_service.dart';
import '../services/biometric_service.dart';
import '../theme.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AutoTransactionService _autoService = AutoTransactionService();
  final BiometricService _bioService = BiometricService();
  bool _isEnabled = false;
  bool _autoConfirm = false;
  bool _biometricEnabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _autoService.loadSettings();
    final hasBio = await _bioService.hasBiometrics();
    setState(() {
      _isEnabled = _autoService.isEnabled;
      _autoConfirm = _autoService.autoConfirm;
      _biometricEnabled = hasBio;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Apparence ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Apparence',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Consumer<ThemeProvider>(
                          builder: (context, themeProvider, _) {
                            return SwitchListTile(
                              title: const Text('Mode sombre'),
                              subtitle: const Text('Activer le thème sombre'),
                              value: themeProvider.isDarkMode,
                              onChanged: (value) {
                                themeProvider.toggleDarkMode();
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Sécurité ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sécurité',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_biometricEnabled)
                          SwitchListTile(
                            title: const Text('Authentification biométrique'),
                            subtitle: const Text('Utiliser empreinte ou FaceID pour vous connecter'),
                            value: true,
                            onChanged: (value) async {
                              if (value) {
                                final authenticated = await _bioService.authenticate();
                                if (!authenticated) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Authentification échouée')),
                                  );
                                }
                              }
                            },
                          )
                        else
                          ListTile(
                            title: const Text('Authentification biométrique'),
                            subtitle: Text(
                              'Non disponible sur cet appareil',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            enabled: false,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Automatisation des transactions ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Automatisation des transactions',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Activer la détection SMS automatique'),
                          subtitle: const Text('Détecte automatiquement les transactions Wave/Orange Money'),
                          value: _isEnabled,
                          onChanged: (value) async {
                            await _autoService.setEnabled(value);
                            setState(() => _isEnabled = value);
                          },
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Confirmation automatique'),
                          subtitle: const Text('Ajoute les transactions sans confirmation'),
                          value: _autoConfirm,
                          onChanged: _isEnabled ? (value) async {
                            await _autoService.setAutoConfirm(value);
                            setState(() => _autoConfirm = value);
                          } : null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Onboarding ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configuration',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: Icon(Icons.school, color: Theme.of(context).colorScheme.primary),
                          title: const Text('Relancer l\'onboarding'),
                          subtitle: const Text('Refaire la configuration initiale'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Informations ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fonctionnalités d\'automatisation',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '• Écoute des SMS en temps réel',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          '• Parsing automatique (Wave, Orange Money)',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          '• Catégorisation automatique des transactions',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          '• Dialog de confirmation avant ajout',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Note: Les SMS ne sont stockés que localement et ne sont pas envoyés à des serveurs externes.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
