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
      'category_name': category, // Envoyer le nom de la catégorie pour matching côté API
    };
  }
}

class SmsParserService {
  final ApiService _api = ApiService();

  // Mapping intelligent basé sur le sender
  static const Map<String, String> _senderToCategory = {
    'wave': 'wave',
    'orange money': 'orange money',
    'orange': 'orange money',
    'free': 'free money',
    'free money': 'free money',
    'wari': 'wari',
  };

  // Mapping complet des catégories vers leurs mots-clés
  static const Map<String, List<String>> _categoryKeywords = {
    // Catégories de dépenses
    'nourriture': ['nourriture', 'food', 'resto', 'restaurant', 'café', 'coffee', 'manger', 'repas', 'déjeuner', 'dîner', 'petit déjeuner'],
    'transport': ['transport', 'taxi', 'bus', 'yango', 'bolt', 'uber', 'clando', 'car', 'véhicule', 'déplacement', 'voyage'],
    'internet / data': ['internet', 'data', 'pass', 'mo', 'mb', 'go', 'gb', 'forfait', 'pack', 'wifi', 'réseau', 'connexion'],
    'wave': ['wave'],
    'orange money': ['orange', 'orange money', 'om'],
    'free money': ['free', 'free money'],
    'wari': ['wari'],
    'proximo': ['proximo'],
    'jumia': ['jumia'],
    'carburant': ['carburant', 'essence', 'gazole', 'fuel', 'station', 'pompe'],
    'électricité': ['électricité', 'electricité', 'sénélec', 'lumière', 'energie'],
    'eau': ['eau', 'sde', 'hydrant'],
    'sénélec': ['sénélec', 'électricité', 'electricité'],
    'sde': ['sde', 'eau'],
    'canal+': ['canal', 'canal+', 'télévision', 'tv'],
    'santé': ['santé', 'médecin', 'hôpital', 'clinique'],
    'pharmacie': ['pharmacie', 'médicament', 'médicaments', 'remède'],
    'école / université': ['école', 'université', 'études', 'cours', 'formation', 'enseignement'],
    'logement': ['logement', 'maison', 'appartement', 'habitation'],
    'loyer': ['loyer', 'location', 'dépôt de garantie'],
    'loisirs': ['loisirs', 'loisir', 'divertissement', 'cinéma', 'sortie', 'fête'],
    'restaurant': ['restaurant', 'resto', 'manger au restaurant'],
    'café': ['café', 'coffee', 'caféteria'],
    'taxi': ['taxi', 'yango', 'bolt', 'uber', 'clando'],
    'bus rapide': ['bus', 'bus rapide', 'tapagal', 'car rapide'],
    'clando': ['clando', 'taxi clando'],
    'transferts famille': ['transfert', 'envoi', 'famille', 'parents', 'proches'],
    'autre': ['autre', 'divers', 'divers'],
    
    // Catégories de revenus
    'revenus': ['revenu', 'revenus', 'argent reçu', 'entré d\'argent'],
    'salaire': ['salaire', 'paye', 'mensuel', 'bulletin', 'fiche de paie'],
    'business': ['business', 'client', 'facture', 'entreprise', 'commercial', 'vente'],
    'investissement': ['investissement', 'placement', 'bourse', 'action', 'rendement'],
    'épargne': ['épargne', 'économie', 'économie d\'argent', 'compte épargne'],
  };

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
    final matchedCategories = _matchCategories(message, categories, type, sender);
    
    // Extraction du solde
    final balance = _extractBalance(message);

    // Génération de la description
    final description = _generateDescription(message, sender, type, matchedCategories);

    // Sélectionner la meilleure catégorie
    String? selectedCategory;
    if (matchedCategories.isNotEmpty) {
      selectedCategory = matchedCategories.first['name'];
    } else {
      // Si aucune catégorie trouvée, utiliser une catégorie par défaut
      if (type == 'expense') {
        selectedCategory = 'Autre';
      } else if (type == 'income') {
        // Pour les revenus, utiliser "Revenus" comme catégorie par défaut
        selectedCategory = 'Revenus';
      }
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
    final taxiSenders = ['Yango', 'YANGO', 'Taxi', 'TAXI', 'Bolt', 'BOLT', 'Uber', 'UBER'];
    final otherSenders = ['Free', 'FREE', 'Expresso', 'EXPRESSO', 'Wari', 'WARI', 'Jonah', 'JONAH'];
    
    final isWave = waveSenders.any((s) => sender.toLowerCase().contains(s.toLowerCase()));
    final isOrange = orangeSenders.any((s) => sender.toLowerCase().contains(s.toLowerCase()));
    final isTaxi = taxiSenders.any((s) => sender.toLowerCase().contains(s.toLowerCase()));
    final isOther = otherSenders.any((s) => sender.toLowerCase().contains(s.toLowerCase()));
    
    // Vérifier aussi dans le body du message
    final lowerMessage = message.toLowerCase();
    final isTransactionInBody = lowerMessage.contains('wave') || 
                                lowerMessage.contains('orange money') ||
                                lowerMessage.contains('yango') ||
                                lowerMessage.contains('taxi') ||
                                lowerMessage.contains('bolt') ||
                                lowerMessage.contains('uber') ||
                                lowerMessage.contains('free') ||
                                lowerMessage.contains('expresso');
    
    if (!isWave && !isOrange && !isTaxi && !isOther && !isTransactionInBody) return false;

    // Vérifie si le message contient un montant
    return _extractAmount(message) != null;
  }

  static double? _extractAmount(String message) {
    print('SmsParserService: Message original: "$message"');
    
    // Pattern pour détecter les montants : XOF, F, FCFA, etc.
    final patterns = [
      // Format: 12 500 FCFA, 12,500 FCFA, 12500 FCFA (avec espaces, virgules ou points)
      RegExp(r'(\d{1,3}(?:[ ,.]\d{3})*(?:[.,]\d+)?)\s*(?:XOF|F|FCFA)'),
      // Format: XOF 12 500, XOF 12,500
      RegExp(r'XOF\s*(\d{1,3}(?:[ ,.]\d{3})*(?:[.,]\d+)?)'),
      // Format: F 12 500, F 12,500
      RegExp(r'F\s*(\d{1,3}(?:[ ,.]\d{3})*(?:[.,]\d+)?)'),
      // Format: 2000000 FCFA (nombre sans séparateurs avec devise)
      RegExp(r'(\d{4,})\s*(?:XOF|F|FCFA)'),
      // Pattern pour montants sans devise (nombres entre 3 et 7 chiffres)
      RegExp(r'\b(\d{3,7})\b'),
      // Pattern pour montants avec unités de données (Mo, MB, Go, GB)
      RegExp(r'(\d+)\s*(?:Mo|MO|MB|Go|GB)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        var amountStr = match.group(1)!.replaceAll(RegExp(r'[ ,.]'), '');
        print('SmsParserService: Montant trouvé: "$amountStr"');
        return double.tryParse(amountStr);
      }
    }

    print('SmsParserService: Aucun montant trouvé');
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
  List<Map<String, dynamic>> _matchCategories(String message, List<dynamic> categories, String type, String sender) {
    final lowerMessage = message.toLowerCase();
    final lowerSender = sender.toLowerCase();
    Map<String, int> scores = {};

    for (final category in categories) {
      final categoryName = (category['name'] ?? '').toString().toLowerCase();
      int score = 0;

      // Bonus basé sur le sender (priorité absolue)
      if (_senderToCategory.containsKey(lowerSender)) {
        final senderCategory = _senderToCategory[lowerSender]!;
        if (categoryName.contains(senderCategory)) {
          score += 10; // Bonus maximum pour matching sender
        }
      }

      // Score basé sur le nom de la catégorie (pondéré par position)
      final nameMatches = categoryName.allMatches(lowerMessage);
      for (final match in nameMatches) {
        // Bonus si le mot est au début du message
        if (match.start < lowerMessage.length * 0.3) {
          score += 5; // Bonus élevé si au début
        } else {
          score += 3; // Score standard
        }
      }

      // Score basé sur les mots-clés de la catégorie
      if (_categoryKeywords.containsKey(categoryName)) {
        final keywords = _categoryKeywords[categoryName]!;
        for (final keyword in keywords) {
          final keywordMatches = keyword.allMatches(lowerMessage);
          for (final match in keywordMatches) {
            // Bonus selon la position du mot-clé
            if (match.start < lowerMessage.length * 0.3) {
              score += 4; // Bonus élevé si au début
            } else {
              score += 2; // Score standard
            }
          }
        }
      }

      // Score basé sur le sender pour les providers spécifiques
      if (lowerMessage.contains('wave') && categoryName.contains('wave')) {
        score += 6; // Bonus très élevé pour Wave
      }
      if (lowerMessage.contains('orange') && categoryName.contains('orange')) {
        score += 6; // Bonus très élevé pour Orange Money
      }
      if (lowerMessage.contains('free') && categoryName.contains('free')) {
        score += 6; // Bonus très élevé pour Free Money
      }
      if (lowerMessage.contains('wari') && categoryName.contains('wari')) {
        score += 6; // Bonus très élevé pour Wari
      }

      // Bonus pour les catégories qui apparaissent plusieurs fois
      if (nameMatches.length > 1) {
        score += nameMatches.length; // Bonus multiplicatif
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
    const Map<String, List<String>> categoryKeywords = {
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

    for (final entry in categoryKeywords.entries) {
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
      return type == 'income' ? 'Transfert' : 'Autre';
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
