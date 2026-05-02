import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import '../services/api_service.dart';
import '../theme.dart';

class FinancialGoalFormScreen extends StatefulWidget {
  final Map<String, dynamic>? financialGoal;

  const FinancialGoalFormScreen({super.key, this.financialGoal});

  @override
  State<FinancialGoalFormScreen> createState() => _FinancialGoalFormScreenState();
}

class _FinancialGoalFormScreenState extends State<FinancialGoalFormScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _currentAmountController = TextEditingController();
  DateTime? _targetDate;
  String _selectedIcon = 'savings';
  String _selectedColor = '#4CAF50';
  bool _loadingSuggestions = true;
  bool _loading = false;

  final List<Map<String, dynamic>> _icons = [
    {'icon': Icons.savings, 'name': 'savings', 'label': 'Épargne'},
    {'icon': Icons.home, 'name': 'home', 'label': 'Maison'},
    {'icon': Icons.directions_car, 'name': 'car', 'label': 'Voiture'},
    {'icon': Icons.school, 'name': 'education', 'label': 'Études'},
    {'icon': Icons.flight, 'name': 'vacation', 'label': 'Voyage'},
    {'icon': Icons.phone, 'name': 'phone', 'label': 'Téléphone'},
    {'icon': Icons.shopping_bag, 'name': 'shopping', 'label': 'Shopping'},
    {'icon': Icons.health_and_safety, 'name': 'health', 'label': 'Santé'},
    {'icon': Icons.laptop, 'name': 'tech', 'label': 'Tech'},
    {'icon': Icons.favorite, 'name': 'wedding', 'label': 'Mariage'},
    {'icon': Icons.elderly, 'name': 'retirement', 'label': 'Retraite'},
  ];

  final List<Map<String, dynamic>> _colors = [
    {'color': '#4CAF50', 'name': 'Vert'},
    {'color': '#2196F3', 'name': 'Bleu'},
    {'color': '#FF9800', 'name': 'Orange'},
    {'color': '#9C27B0', 'name': 'Violet'},
    {'color': '#F44336', 'name': 'Rouge'},
    {'color': '#607D8B', 'name': 'Gris'},
  ];

  final List<Map<String, dynamic>> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
    if (widget.financialGoal != null) {
      _nameController.text = widget.financialGoal!['name'] ?? '';
      _descriptionController.text = widget.financialGoal!['description'] ?? '';
      _targetAmountController.text = widget.financialGoal!['target_amount']?.toString() ?? '';
      _currentAmountController.text = widget.financialGoal!['current_amount']?.toString() ?? '';
      if (widget.financialGoal!['target_date'] != null) {
        _targetDate = DateTime.parse(widget.financialGoal!['target_date']);
      }
      _selectedIcon = widget.financialGoal!['icon'] ?? 'savings';
      _selectedColor = widget.financialGoal!['color'] ?? '#4CAF50';
    }
  }

  Future<void> _loadSuggestions() async {
    try {
      final response = await _api.get('/financial-goals/suggestions');
      setState(() {
        _suggestions.clear();
        if (response != null && response['data'] != null) {
          _suggestions.addAll((response['data'] as List).map((item) => {
            'name': item['name'],
            'target': item['target_amount'],
            'icon': item['icon'],
          }).toList());
        } else {
          // Utiliser des suggestions par défaut si pas de réponse
          _suggestions.addAll([
            {'name': 'Achat voiture', 'target': 5000000, 'icon': 'car'},
            {'name': 'Achat maison', 'target': 20000000, 'icon': 'home'},
            {'name': 'Voyage', 'target': 1500000, 'icon': 'vacation'},
            {'name': 'Fonds d\'urgence', 'target': 1000000, 'icon': 'savings'},
            {'name': 'Études', 'target': 3000000, 'icon': 'education'},
            {'name': 'Téléphone', 'target': 500000, 'icon': 'phone'},
          ]);
        }
        _loadingSuggestions = false;
      });
    } catch (e) {
      // En cas d'erreur, utiliser des suggestions par défaut
      setState(() {
        _suggestions.clear();
        _suggestions.addAll([
          {'name': 'Achat voiture', 'target': 5000000, 'icon': 'car'},
          {'name': 'Achat maison', 'target': 20000000, 'icon': 'home'},
          {'name': 'Voyage', 'target': 1500000, 'icon': 'vacation'},
          {'name': 'Fonds d\'urgence', 'target': 1000000, 'icon': 'savings'},
          {'name': 'Études', 'target': 3000000, 'icon': 'education'},
          {'name': 'Téléphone', 'target': 500000, 'icon': 'phone'},
        ]);
        _loadingSuggestions = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _targetAmountController.dispose();
    _currentAmountController.dispose();
    super.dispose();
  }

  void _applySuggestion(Map<String, dynamic> suggestion) {
    setState(() {
      _nameController.text = suggestion['name'];
      _targetAmountController.text = suggestion['target_amount']?.toString() ?? suggestion['target']?.toString() ?? '';
      _selectedIcon = suggestion['icon'];
    });
  }

  IconData _getIconData(String iconName) {
    final icon = _icons.firstWhere((i) => i['name'] == iconName, orElse: () => _icons[0]);
    return icon['icon'];
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_targetAmountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un montant cible')),
      );
      return;
    }

    final data = {
      'name': _nameController.text,
      'description': _descriptionController.text,
      'target_amount': double.tryParse(_targetAmountController.text) ?? 0,
      'current_amount': _currentAmountController.text.isEmpty ? 0 : double.tryParse(_currentAmountController.text) ?? 0,
      'target_date': _targetDate?.toIso8601String().split('T').first,
      'icon': _selectedIcon,
      'color': _selectedColor,
    };

    print('Données envoyées: $data');

    try {
      setState(() => _loading = true);
      if (widget.financialGoal != null) {
        print('Modification objectif ID: ${widget.financialGoal!['id']}');
        await _api.put('/financial-goals/${widget.financialGoal!['id']}', data);
      } else {
        print('Création nouvel objectif');
        final response = await _api.post('/financial-goals', data);
        print('Réponse création: $response');
      }
      if (mounted) {
        print('Sauvegarde réussie, retour true');
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Erreur sauvegarde: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sauvegarde: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    double currentAmount = _currentAmountController.text.isEmpty ? 0 : double.tryParse(_currentAmountController.text) ?? 0;
    double targetAmount = double.tryParse(_targetAmountController.text) ?? 0;
    double progress = targetAmount > 0 ? (currentAmount / targetAmount) * 100 : 0;
    Color previewColor = Color(int.parse(_selectedColor.replaceAll('#', '0xFF')));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.financialGoal != null ? 'Modifier l\'objectif' : 'Nouvel objectif'),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Aperçu en temps réel
                  if (_nameController.text.isNotEmpty || targetAmount > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [previewColor, previewColor.withValues(alpha: 0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppTheme.softShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(_getIconData(_selectedIcon), color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _nameController.text.isEmpty ? 'Nouvel objectif' : _nameController.text,
                                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppTheme.formatCurrency(currentAmount),
                                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      'sur ${targetAmount > 0 ? AppTheme.formatCurrency(targetAmount) : '0 FCFA'}',
                                      style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${progress.toStringAsFixed(0)}%',
                                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // Suggestions pour nouveaux objectifs
                  if (widget.financialGoal == null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Suggestions rapides',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        if (_loadingSuggestions)
                          const SizedBox(
                            height: 100,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_suggestions.isNotEmpty)
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _suggestions.length,
                              itemBuilder: (_, i) {
                                final suggestion = _suggestions[i];
                                return Container(
                                  width: 140,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () => _applySuggestion(suggestion),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(_getIconData(suggestion['icon']), size: 24, color: cs.primary),
                                            const SizedBox(height: 8),
                                            Text(
                                              suggestion['name'],
                                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              AppTheme.formatCurrency(suggestion['target_amount'] ?? suggestion['target']),
                                              style: GoogleFonts.inter(fontSize: 10, color: cs.onSurfaceVariant),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          const SizedBox(
                            height: 100,
                            child: Center(child: Text('Aucune suggestion disponible')),
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),

                  // Section informations
                  _SectionCard(
                    title: 'Informations',
                    icon: Icons.info_outline,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Nom de l\'objectif *',
                            prefixIcon: const Icon(Icons.flag),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) => value?.isEmpty ?? true ? 'Champ requis' : null,
                        ),
                        const Gap(16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            prefixIcon: const Icon(Icons.notes),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),

                  const Gap(16),

                  // Section montant
                  _SectionCard(
                    title: 'Montant',
                    icon: Icons.account_balance_wallet,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _targetAmountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Montant cible (FCFA) *',
                            prefixIcon: const Icon(Icons.trending_up),
                            suffixText: 'FCFA',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) => value?.isEmpty ?? true ? 'Champ requis' : null,
                        ),
                        const Gap(16),
                        TextFormField(
                          controller: _currentAmountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Montant actuel (FCFA)',
                            prefixIcon: const Icon(Icons.account_balance_wallet),
                            suffixText: 'FCFA',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Gap(16),

                  // Section date
                  _SectionCard(
                    title: 'Date cible',
                    icon: Icons.calendar_today,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.calendar_today, color: cs.primary, size: 20),
                      ),
                      title: const Text('Date cible'),
                      subtitle: Text(_targetDate != null
                          ? DateFormat('dd MMMM yyyy', 'fr_FR').format(_targetDate!)
                          : 'Sélectionner'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _targetDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(DateTime.now().year + 10),
                        );
                        if (date != null) {
                          setState(() => _targetDate = date);
                        }
                      },
                    ),
                  ),

                  const Gap(16),

                  // Section personnalisation
                  _SectionCard(
                    title: 'Personnalisation',
                    icon: Icons.palette,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Icône', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                        const Gap(8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _icons.map((iconData) {
                            return _IconChoice(
                              icon: iconData['icon'],
                              label: iconData['label'] ?? '',
                              isSelected: _selectedIcon == iconData['name'],
                              onTap: () => setState(() => _selectedIcon = iconData['name']),
                            );
                          }).toList(),
                        ),
                        const Gap(16),
                        Text('Couleur', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                        const Gap(8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _colors.map((colorData) {
                            return _ColorChoice(
                              color: colorData['color'],
                              name: colorData['name'],
                              isSelected: _selectedColor == colorData['color'],
                              onTap: () => setState(() => _selectedColor = colorData['color']),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const Gap(24),
                ],
              ),
            ),
            // Bouton en bas
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: FilledButton(
                onPressed: _loading ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: _loading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _IconChoice({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.15) : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: isSelected ? AppTheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: isSelected ? AppTheme.primary : Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  final String color;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorChoice({
    required this.color,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorValue = Color(int.parse(color.replaceAll('#', '0xFF')));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colorValue.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? colorValue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: colorValue,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? colorValue : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
