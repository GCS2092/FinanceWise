import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final ApiService _api = ApiService();
  
  // Données onboarding
  final _incomeController = TextEditingController();
  final List<Map<String, dynamic>> _wallets = [];
  final List<Map<String, dynamic>> _budgets = [];
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
  ];

  Future<void> _completeOnboarding() async {
    setState(() => _loading = true);
    
    try {
      // Sauvegarder les données onboarding
      final response = await _api.post('/user/onboarding', {
        'monthly_income_target': double.tryParse(_incomeController.text) ?? 0,
        'wallets': _wallets,
        'budgets': _budgets,
      });
      
      if (mounted) {
        final walletsCreated = response['wallets_created'] ?? 0;
        final budgetsCreated = response['budgets_created'] ?? 0;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Onboarding terminé ! $walletsCreated portefeuilles créés, $budgetsCreated budgets créés'),
            backgroundColor: AppTheme.primary,
          ),
        );
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
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
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _addWallet() {
    setState(() {
      _wallets.add({
        'name': '',
        'balance': 0,
        'type': 'cash',
      });
    });
  }

  void _removeWallet(int index) {
    setState(() {
      _wallets.removeAt(index);
    });
  }

  void _addBudget() {
    setState(() {
      _budgets.add({
        'category_id': null,
        'amount': 0,
        'period': 'monthly',
      });
    });
  }

  void _removeBudget(int index) {
    setState(() {
      _budgets.removeAt(index);
    });
  }

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
      }
    } catch (e) {
      setState(() {
        _loadingCategories = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  return _buildStep(_steps[index]);
                },
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
                      color: _currentPage == index 
                          ? AppTheme.primary 
                          : AppTheme.outlineVariant,
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
    if (!step.isInteractive) {
      return _buildInfoStep(step);
    } else {
      switch (step.title) {
        case 'Définissez votre revenu mensuel':
          return _buildIncomeStep(step);
        case 'Configurez vos portefeuilles':
          return _buildWalletsStep(step);
        case 'Définissez vos budgets (optionnel)':
          return _buildBudgetsStep(step);
        default:
          return _buildInfoStep(step);
      }
    }
  }

  Widget _buildInfoStep(OnboardingStep step) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
            if (step.title == 'Découvrez les fonctionnalités') ...[
              const SizedBox(height: 32),
              _buildFeaturesGuide(),
            ],
            if (step.title == 'Votre Dashboard') ...[
              const SizedBox(height: 32),
              _buildDashboardGuide(),
            ],
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentPage > 0)
                  TextButton(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: const Text('Précédent'),
                  ),
                if (_currentPage < _steps.length - 1)
                  ElevatedButton(
                    onPressed: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: const Text('Suivant'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeStep(OnboardingStep step) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(step.icon, size: 40, color: AppTheme.primary),
          ),
          const SizedBox(height: 32),
          Text(
            step.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            step.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
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
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: const Text('Précédent'),
              ),
              ElevatedButton(
                onPressed: () {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: const Text('Suivant'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWalletsStep(OnboardingStep step) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
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
          const SizedBox(height: 24),
          Text(
            step.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            step.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _wallets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, 
                             size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun portefeuille ajouté',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cliquez sur + pour ajouter',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _wallets.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.account_balance),
                          title: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Nom',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (value) {
                              _wallets[index]['name'] = value;
                            },
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                            onPressed: () => _removeWallet(index),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addWallet,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: const Text('Suivant'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: const Text('Précédent'),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetsStep(OnboardingStep step) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
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
          const SizedBox(height: 24),
          Text(
            step.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            step.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '(Optionnel - Vous pourrez ajouter des budgets plus tard)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _budgets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pie_chart_outline, 
                             size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun budget défini',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cliquez sur + pour ajouter (optionnel)',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _budgets.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                  items: _categories.map((cat) {
                                    return DropdownMenuItem<int>(
                                      value: cat['id'],
                                      child: Text(cat['name'] ?? ''),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _budgets[index]['category_id'] = value;
                                    });
                                  },
                                ),
                              const SizedBox(height: 8),
                              TextField(
                                decoration: InputDecoration(
                                  labelText: 'Montant (FCFA)',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  _budgets[index]['amount'] = double.tryParse(value) ?? 0;
                                },
                              ),
                              const SizedBox(height: 4),
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
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addBudget,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: const Text('Suivant'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: const Text('Précédent'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesGuide() {
    final features = [
      {
        'icon': Icons.receipt_long,
        'title': 'Transactions',
        'description': 'Ajoutez et gérez toutes vos dépenses et revenus. Swipe pour modifier ou supprimer.',
      },
      {
        'icon': Icons.category,
        'title': 'Catégories',
        'description': 'Organisez vos dépenses par catégorie (Nourriture, Transport, Wave, Orange Money, etc.).',
      },
      {
        'icon': Icons.pie_chart,
        'title': 'Budgets',
        'description': 'Définissez des limites par catégorie et recevez des alertes automatiques.',
      },
      {
        'icon': Icons.notifications_active,
        'title': 'Rappels',
        'description': 'Créez des rappels pour vos factures (loyer, Sénélec, SDE, Canal+).',
      },
      {
        'icon': Icons.bar_chart,
        'title': 'Statistiques',
        'description': 'Visualisez vos dépenses avec des graphiques détaillés par catégorie.',
      },
      {
        'icon': Icons.sms,
        'title': 'Parser SMS',
        'description': 'Collez vos SMS Wave/Orange Money pour les ajouter automatiquement.',
      },
    ];

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: features.length,
        itemBuilder: (context, index) {
          final feature = features[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.teal.withValues(alpha: 0.1),
                child: Icon(feature['icon'] as IconData, color: Colors.teal, size: 20),
              ),
              title: Text(feature['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(feature['description'] as String, style: const TextStyle(fontSize: 12)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDashboardGuide() {
    final sections = [
      {
        'icon': Icons.account_balance_wallet,
        'title': 'Solde Total',
        'description': 'Somme de tous vos portefeuilles (Wave, Orange Money, Banque, Espèces).',
      },
      {
        'icon': Icons.trending_up,
        'title': 'Revenus du Mois',
        'description': 'Total des revenus enregistrés ce mois-ci.',
      },
      {
        'icon': Icons.trending_down,
        'title': 'Dépenses du Mois',
        'description': 'Total des dépenses enregistrées ce mois-ci.',
      },
      {
        'icon': Icons.pie_chart,
        'title': 'Répartition',
        'description': 'Graphique montrant la répartition de vos dépenses par catégorie.',
      },
      {
        'icon': Icons.notifications,
        'title': 'Alertes',
        'description': 'Notifications si vous dépassez vos budgets.',
      },
      {
        'icon': Icons.list,
        'title': 'Transactions Récentes',
        'description': 'Dernières transactions ajoutées.',
      },
    ];

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final section = sections[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.indigo.withValues(alpha: 0.1),
                child: Icon(section['icon'] as IconData, color: Colors.indigo, size: 20),
              ),
              title: Text(section['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(section['description'] as String, style: const TextStyle(fontSize: 12)),
            ),
          );
        },
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
