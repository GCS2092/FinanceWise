import 'api_service.dart';

class SmsTransaction {
  final double amount;
  final String type; // 'income' or 'expense'
  final String? category; // category name
  final String description;
  final DateTime date;
  final String? sender;
  final double? balance;
  final String? originalSms;
  final List<String> matchedCategories; // list of matched category IDs

  SmsTransaction({
    required this.amount,
    required this.type,
    this.category,
    required this.description,
    required this.date,
    this.sender,
    this.balance,
    this.originalSms,
    this.matchedCategories = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'type': type == 'income' ? 'income' : 'expense',
      'description': description,
      'transaction_date': date.toIso8601String(),
      'sender': sender,
      'balance': balance,
    };
  }
}

class SmsParserService {
  final ApiService _api = ApiService();

  // Mots-clés génériques pour la détection de type
  static const List<String> _creditKeywords = [
    'reçu', 'crédit', 'recu', 'credit', 'déposé', 'deposit', 'entré', 'entree',
    'encaissement', 'reception', 'recu', 'gagné', 'gagne', 'versement',
    'ajouté', 'ajoute', 'crédité', 'credite', 'receptionné', 'recptionne'
  ];
  
  static const List<String> _debitKeywords = [
    'envoyé', 'envoye', 'payé', 'paye', 'débit', 'debit', 'sorti', 'sortie',
    'transfert', 'paiement', 'achat', 'dépense', 'depense', 'retrait', 'cash',
    'déduit', 'deduit', 'prélevé', 'preleve', 'déboursé', 'debourse',
    'versé', 'verse', 'retiré', 'retire', 'dépensé', 'depense', 'max', 'montant',
    'sommes', 'somme', 'argent', 'argent', 'coût', 'cout', 'prix', 'reglement',
    'reglement', 'facture', 'ticket', 'commande', 'commande'
  ];

  // Parser avec les catégories existantes
  Future<SmsTransaction?> parseSmsWithCategories(String message, String sender) async {
    // Détection si c'est un SMS de Wave ou Orange Money
    if (!_isTransactionSms(message, sender)) {
      return null;
    }

    // Extraction du montant
    final amount = _extractAmount(message);
    if (amount == null) return null;

    // Détermination du type (crédit ou débit)
    final type = _determineType(message, sender);

    // Charger les catégories depuis l'API
    List<dynamic> categories = [];
    try {
      final result = await _api.get('/categories');
      if (result is Map && result.containsKey('data')) {
        categories = result['data'] as List;
      } else if (result is List) {
        categories = result;
      }
    } catch (e) {
      // En cas d'erreur, utiliser les catégories par défaut
    }

    // Classification avec les catégories existantes
    final matchedCategories = _matchCategories(message, categories, type);
    
    // Extraction du solde
    final balance = _extractBalance(message);

    // Génération de la description
    final description = _generateDescription(message, sender, type, matchedCategories);

    // Sélectionner la meilleure catégorie
    String? selectedCategory;
    if (matchedCategories.isNotEmpty) {
      selectedCategory = matchedCategories.first['name'];
    }

    return SmsTransaction(
      amount: amount,
      type: type,
      category: selectedCategory,
      description: description,
      date: DateTime.now(),
      sender: sender,
      balance: balance,
      originalSms: message,
      matchedCategories: matchedCategories.map((c) => c['id'].toString()).toList(),
    );
  }

  // Parser sans catégories (ancienne méthode pour compatibilité)
  static SmsTransaction? parseSms(String message, String sender) {
    // Détection si c'est un SMS de Wave ou Orange Money
    if (!_isTransactionSms(message, sender)) {
      return null;
    }

    // Extraction du montant
    final amount = _extractAmount(message);
    if (amount == null) return null;

    // Détermination du type (crédit ou débit)
    final type = _determineType(message, sender);

    // Classification automatique de la catégorie (ancienne méthode)
    final category = _classifyCategory(message, sender, type);

    // Extraction du solde
    final balance = _extractBalance(message);

    // Génération de la description
    final description = _generateDescription(message, sender, type, []);

    return SmsTransaction(
      amount: amount,
      type: type,
      category: category,
      description: description,
      date: DateTime.now(),
      sender: sender,
      balance: balance,
      originalSms: message,
    );
  }

  static bool _isTransactionSms(String message, String sender) {
    // Vérifie si le sender est Wave ou Orange Money
    final waveSenders = ['Wave', 'WAVE', 'Wave SN', 'WAVE SENEGAL'];
    final orangeSenders = ['Orange Money', 'ORANGE MONEY', 'Orange', 'ORANGE'];
    
    final isWave = waveSenders.any((s) => sender.toLowerCase().contains(s.toLowerCase()));
    final isOrange = orangeSenders.any((s) => sender.toLowerCase().contains(s.toLowerCase()));
    
    if (!isWave && !isOrange) return false;

    // Vérifie si le message contient un montant
    return _extractAmount(message) != null;
  }

  static double? _extractAmount(String message) {
    // Pattern pour détecter les montants : XOF, F, FCFA, etc.
    final patterns = [
      RegExp(r'(\d+[.,]\d+)\s*(?:XOF|F|FCFA)'),
      RegExp(r'(\d+)\s*(?:XOF|F|FCFA)'),
      RegExp(r'XOF\s*(\d+[.,]\d+)'),
      RegExp(r'F\s*(\d+[.,]\d+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final amountStr = match.group(1)!.replaceAll(',', '.');
        return double.tryParse(amountStr);
      }
    }

    return null;
  }

  static String _determineType(String message, String sender) {
    final lowerMessage = message.toLowerCase();

    for (final keyword in _creditKeywords) {
      if (lowerMessage.contains(keyword)) {
        return 'income';
      }
    }

    for (final keyword in _debitKeywords) {
      if (lowerMessage.contains(keyword)) {
        return 'expense';
      }
    }

    // Par défaut, considérer comme débit
    return 'expense';
  }

  // Matcher les catégories basées sur les mots-clés dans le SMS
  List<Map<String, dynamic>> _matchCategories(String message, List<dynamic> categories, String type) {
    final lowerMessage = message.toLowerCase();
    Map<String, int> scores = {};

    for (final category in categories) {
      final categoryName = (category['name'] ?? '').toString().toLowerCase();
      int score = 0;

      // Score basé sur le nom de la catégorie
      if (lowerMessage.contains(categoryName)) {
        score += 3;
      }

      // Score basé sur des mots-clés génériques
      if (type == 'expense') {
        final expenseKeywords = ['dépense', 'depense', 'paiement', 'paye', 'achat', 'paye'];
        for (final keyword in expenseKeywords) {
          if (lowerMessage.contains(keyword) && categoryName.contains(keyword)) {
            score += 2;
          }
        }
      }

      if (score > 0) {
        scores[category['id'].toString()] = score;
      }
    }

    // Trier par score
    final sortedScores = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Retourner les catégories correspondantes triées
    List<Map<String, dynamic>> matched = [];
    for (final entry in sortedScores) {
      final category = categories.firstWhere(
        (c) => c['id'].toString() == entry.key,
        orElse: () => null,
      );
      if (category != null) {
        matched.add(category);
      }
    }

    return matched;
  }

  static String _classifyCategory(String message, String sender, String type) {
    final lowerMessage = message.toLowerCase();
    
    // Mots-clés par catégorie pour la classification automatique
    const Map<String, List<String>> _categoryKeywords = {
      'Alimentation': ['restaurant', 'café', 'fast food', 'snack', 'manger', 'repas', 'food', 'aliment'],
      'Transport': ['taxi', 'bus', 'car', 'véhicule', 'transport', 'essence', 'carburant', 'gazoil'],
      'Téléphone': ['orange', 'wave', 'free', 'expresso', 'internet', 'data', 'appel', 'sms', 'credit'],
      'Shopping': ['boutique', 'magasin', 'shopping', 'achat', 'market', 'supermarché', 'mall'],
      'Santé': ['pharmacie', 'médecin', 'hôpital', 'santé', 'clinique', 'médicament'],
      'Divertissement': ['cinéma', 'concert', 'spectacle', 'jeu', 'loisir', 'fun', 'sport'],
      'Factures': ['eau', 'électricité', 'senelec', 'sde', 'facture', 'abonnement'],
      'Transfert': ['envoi', 'transfert', 'reception', 'envoyé', 'reçu', 'cash'],
      'Retrait': ['retrait', 'cash', 'espèces', 'argent'],
    };

    // Score pour chaque catégorie
    Map<String, int> scores = {};

    for (final entry in _categoryKeywords.entries) {
      final category = entry.key;
      final keywords = entry.value;
      
      int score = 0;
      for (final keyword in keywords) {
        if (lowerMessage.contains(keyword.toLowerCase())) {
          score++;
        }
      }
      
      if (score > 0) {
        scores[category] = score;
      }
    }

    // Si aucune catégorie trouvée, utiliser une catégorie par défaut
    if (scores.isEmpty) {
      return type == 'income' ? 'Transfert' : 'Dépenses diverses';
    }

    // Retourner la catégorie avec le score le plus élevé
    final sortedScores = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedScores.first.key;
  }

  static double? _extractBalance(String message) {
    // Pattern pour détecter le solde après transaction
    final patterns = [
      RegExp(r'solde\s*:?\s*(\d+[.,]\d+)\s*(?:XOF|F|FCFA)'),
      RegExp(r'balance\s*:?\s*(\d+[.,]\d+)\s*(?:XOF|F|FCFA)'),
      RegExp(r'votre\s+solde\s+est\s+(\d+[.,]\d+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final balanceStr = match.group(1)!.replaceAll(',', '.');
        return double.tryParse(balanceStr);
      }
    }

    return null;
  }

  static String _generateDescription(String message, String sender, String type, List<dynamic> matchedCategories) {
    // Génère une description basée sur le sender et le type
    final senderName = sender.contains('Wave') ? 'Wave' : 'Orange Money';
    
    if (type == 'income') {
      return 'Transaction $senderName - Reçu';
    } else {
      return 'Transaction $senderName - Dépense';
    }
  }
}
