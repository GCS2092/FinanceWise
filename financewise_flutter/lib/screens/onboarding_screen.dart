import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import '../services/api_service.dart';
import '../theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final ApiService _api = ApiService();

  final _incomeController = TextEditingController();
  final List<Map<String, dynamic>> _wallets = [];
  final List<Map<String, dynamic>> _budgets = [];
  final List<Map<String, dynamic>> _goals = [];
  bool _loading = false;
  List<dynamic> _categories = [];
  bool _loadingCategories = true;

  final List<OnboardingStep> _steps = [
    OnboardingStep(
      title: 'Bienvenue sur FinanceWise',
      description: 'Votre assistant financier personnel pour gérer vos finances au Sénégal.',
      icon: Icons.account_balance_wallet,
      color: AppTheme.primary,
      isInteractive: false,
    ),
    OnboardingStep(
      title: 'Définissez votre revenu mensuel',
      description: 'Entrez votre revenu mensuel estimé pour suivre vos finances et recevoir des alertes intelligentes.',
      icon: Icons.attach_money,
      color: AppTheme.primary,
      isInteractive: true,
    ),
    OnboardingStep(
      title: 'Configurez vos portefeuilles',
      description: 'Ajoutez vos comptes : Wave, Orange Money, Banque, Espèces, etc.',
      icon: Icons.account_balance,
      color: AppTheme.tertiary,
      isInteractive: true,
    ),
    OnboardingStep(
      title: 'Définissez vos budgets (optionnel)',
      description: 'Créez des budgets par catégorie pour contrôler vos dépenses.',
      icon: Icons.pie_chart,
      color: AppTheme.secondary,
      isInteractive: true,
    ),
    OnboardingStep(
      title: 'Définissez vos objectifs (optionnel)',
      description: 'Fixez-vous des objectifs d\'épargne : voiture, maison, voyage, etc.',
      icon: Icons.flag,
      color: AppTheme.success,
      isInteractive: true,
    ),
    OnboardingStep(
      title: 'Activez les notifications',
      description: 'Recevez des alertes pour vos budgets, revenus et objectifs.',
      icon: Icons.notifications_active,
      color: AppTheme.warning,
      isInteractive: true,
    ),
    OnboardingStep(
      title: 'Sécurisez votre compte',
      description: 'Activez la biométrie pour une connexion rapide et sécurisée.',
      icon: Icons.fingerprint,
      color: AppTheme.primary,
      isInteractive: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final result = await _api.get('/categories');
      if (result is Map && result['data'] is List) {
        setState(() {
          _categories = result['data'];
          _loadingCategories = false;
        });
      } else if (result is List) {
        setState(() {
          _categories = result;
          _loadingCategories = false;
        });
      } else {
        setState(() => _loadingCategories = false);
      }
    } catch (e) {
      setState(() => _loadingCategories = false);
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() => _loading = true);

    try {
      final response = await _api.post('/user/onboarding', {
        'monthly_income_target': double.tryParse(_incomeController.text) ?? 0,
        'wallets': _wallets,
        'budgets': _budgets,
        'goals': _goals,
      });

      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_completed', true);

        final walletsCreated = response['wallets_created'] ?? 0;
        final budgetsCreated = response['budgets_created'] ?? 0;
        final goalsCreated = response['goals_created'] ?? 0;

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Onboarding terminé ! $walletsCreated portefeuilles, $budgetsCreated budgets, $goalsCreated objectifs créés'),
            backgroundColor: AppTheme.primary,
          ),
        );

        if (!mounted) return;
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool get _isLastPage => _currentPage == _steps.length - 1;

  void _addWallet() async {
    setState(() {
      _wallets.add({'name': '', 'balance': 0, 'type': 'cash'});
    });
    try {
      await _api.post('/wallets', {'name': '', 'balance': 0, 'type': 'cash'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Portefeuille ajouté !'), backgroundColor: AppTheme.success, duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'ajout du portefeuille'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _removeWallet(int index) => setState(() => _wallets.removeAt(index));

  void _addBudget() {
    setState(() => _budgets.add({'category_id': null, 'amount': 0, 'period': 'monthly'}));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Budget ajouté !'), backgroundColor: AppTheme.success, duration: Duration(seconds: 2)),
      );
    }
  }

  void _removeBudget(int index) => setState(() => _budgets.removeAt(index));

  void _addGoal() => setState(() => _goals.add({'name': '', 'target_amount': 0, 'icon': 'savings', 'color': '#4CAF50'}));

  void _removeGoal(int index) => setState(() => _goals.removeAt(index));

  @override
  void dispose() {
    _pageController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Configuration'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _completeOnboarding,
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Terminer'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _steps.length,
                itemBuilder: (context, index) => _buildStep(_steps[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _steps.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: _currentPage == index ? 24 : 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index ? AppTheme.primary : AppTheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(OnboardingStep step) {
    if (!step.isInteractive) return _buildInfoStep(step);
    switch (step.title) {
      case 'Définissez votre revenu mensuel':
        return _buildIncomeStep(step);
      case 'Configurez vos portefeuilles':
        return _buildWalletsStep(step);
      case 'Définissez vos budgets (optionnel)':
        return _buildBudgetsStep(step);
      case 'Définissez vos objectifs (optionnel)':
        return _buildGoalsStep(step);
      case 'Activez les notifications':
        return _buildNotificationsStep(step);
      case 'Sécurisez votre compte':
        return _buildBiometricStep(step);
      default:
        return _buildInfoStep(step);
    }
  }

  // ── Navigation buttons helper ──────────────────────────────────────────────

  Widget _buildNavButtons({bool showPrev = true}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (showPrev && _currentPage > 0)
          TextButton(onPressed: _previousPage, child: const Text('Précédent'))
        else
          const SizedBox.shrink(),
        _isLastPage
            ? ElevatedButton(
                onPressed: _loading ? null : _completeOnboarding,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Terminer'),
              )
            : ElevatedButton(onPressed: _nextPage, child: const Text('Suivant')),
      ],
    );
  }

  // ── Steps ──────────────────────────────────────────────────────────────────

  Widget _buildInfoStep(OnboardingStep step) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (step.title == 'Bienvenue sur FinanceWise')
              Lottie.asset(
                'assets/animations/welcome.json',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: step.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: Icon(step.icon, size: 60, color: step.color),
                ),
              )
            else
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: step.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(60),
                ),
                child: Icon(step.icon, size: 60, color: step.color),
              ),
            const SizedBox(height: 48),
            Text(
              step.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              step.description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildNavButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeStep(OnboardingStep step) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: AppTheme.primaryContainer, borderRadius: BorderRadius.circular(40)),
              child: Icon(step.icon, size: 40, color: AppTheme.primary),
            ),
            const SizedBox(height: 32),
            Text(step.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(step.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            TextField(
              controller: _incomeController,
              decoration: InputDecoration(
                labelText: 'Revenu mensuel (FCFA)',
                prefixIcon: const Icon(Icons.money),
                suffixText: 'FCFA',
                hintText: 'Ex: 300000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cette information permet de comparer vos revenus réels avec vos objectifs.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildNavButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletsStep(OnboardingStep step) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _stepHeader(step),
          const SizedBox(height: 16),
          _wallets.isEmpty
              ? _emptyState(Icons.account_balance_wallet_outlined, 'Aucun portefeuille ajouté', 'Cliquez sur + pour ajouter')
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _wallets.length,
                  itemBuilder: (context, index) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.account_balance, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    labelText: 'Nom',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onChanged: (v) => _wallets[index]['name'] = v,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                                onPressed: () => _removeWallet(index),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Solde initial (FCFA)',
                              prefixIcon: Icon(Icons.money),
                              suffixText: 'FCFA',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => _wallets[index]['balance'] = double.tryParse(v) ?? 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _addWallet, icon: const Icon(Icons.add), label: const Text('Ajouter un portefeuille')),
          const SizedBox(height: 8),
          _buildNavButtons(),
        ],
      ),
    );
  }

  Widget _buildBudgetsStep(OnboardingStep step) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _stepHeader(step),
          Text('(Optionnel)', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          _budgets.isEmpty
              ? _emptyState(Icons.pie_chart_outline, 'Aucun budget défini', 'Cliquez sur + pour ajouter (optionnel)')
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _budgets.length,
                  itemBuilder: (context, index) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            if (_loadingCategories)
                              const CircularProgressIndicator()
                            else
                              DropdownButtonFormField<int>(
                                decoration: InputDecoration(
                                  labelText: 'Catégorie',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                value: _budgets[index]['category_id'],
                                hint: const Text('Sélectionner une catégorie'),
                                items: _categories.map((cat) => DropdownMenuItem<int>(
                                  value: cat['id'],
                                  child: Text(cat['name'] ?? ''),
                                )).toList(),
                                onChanged: (v) => setState(() => _budgets[index]['category_id'] = v),
                              ),
                            const SizedBox(height: 8),
                            TextField(
                              decoration: InputDecoration(
                                labelText: 'Montant (FCFA)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (v) => _budgets[index]['amount'] = double.tryParse(v) ?? 0,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                                onPressed: () => _removeBudget(index),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _addBudget, icon: const Icon(Icons.add), label: const Text('Ajouter un budget')),
          const SizedBox(height: 8),
          _buildNavButtons(),
        ],
      ),
    );
  }

  Widget _buildGoalsStep(OnboardingStep step) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _stepHeader(step),
          Text('(Optionnel)', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          _goals.isEmpty
              ? _emptyState(Icons.flag_outlined, 'Aucun objectif défini', 'Cliquez sur + pour ajouter (optionnel)')
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _goals.length,
                  itemBuilder: (context, index) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          TextField(
                            decoration: InputDecoration(
                              labelText: 'Nom de l\'objectif',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onChanged: (v) => _goals[index]['name'] = v,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            decoration: InputDecoration(
                              labelText: 'Montant cible (FCFA)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => _goals[index]['target_amount'] = double.tryParse(v) ?? 0,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                              onPressed: () => _removeGoal(index),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _addGoal, icon: const Icon(Icons.add), label: const Text('Ajouter un objectif')),
          const SizedBox(height: 8),
          _buildNavButtons(),
        ],
      ),
    );
  }

  Widget _buildNotificationsStep(OnboardingStep step) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _stepHeader(step),
          const SizedBox(height: 16),
          Card(child: SwitchListTile(
            title: const Text('Alertes budget'),
            subtitle: const Text('Soyez notifié quand vous dépassez un budget'),
            value: true, onChanged: (v) {},
          )),
          const SizedBox(height: 8),
          Card(child: SwitchListTile(
            title: const Text('Alertes revenu'),
            subtitle: const Text('Soyez notifié quand vous atteignez vos revenus'),
            value: true, onChanged: (v) {},
          )),
          const SizedBox(height: 8),
          Card(child: SwitchListTile(
            title: const Text('Alertes objectifs'),
            subtitle: const Text('Soyez notifié quand vous atteignez vos objectifs'),
            value: true, onChanged: (v) {},
          )),
          const SizedBox(height: 16),
          _buildNavButtons(),
        ],
      ),
    );
  }

  Widget _buildBiometricStep(OnboardingStep step) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _stepHeader(step),
          const SizedBox(height: 32),
          Icon(Icons.fingerprint, size: 80, color: AppTheme.primary),
          const SizedBox(height: 16),
          Text('Appuyez sur le bouton pour activer',
              style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('(Optionnel - Vous pourrez l\'activer plus tard)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
              textAlign: TextAlign.center),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Biométrie activée !'), backgroundColor: AppTheme.success),
              );
            },
            icon: const Icon(Icons.fingerprint),
            label: const Text('Activer la biométrie'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
          ),
          const SizedBox(height: 32),
          // Dernière page → bouton Terminer
          _buildNavButtons(),
        ],
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  Widget _stepHeader(OnboardingStep step) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: step.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Icon(step.icon, size: 30, color: step.color),
        ),
        const SizedBox(height: 16),
        Text(step.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(step.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
        ],
      ),
    );
  }
}

class OnboardingStep {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isInteractive;

  OnboardingStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isInteractive,
  });
}