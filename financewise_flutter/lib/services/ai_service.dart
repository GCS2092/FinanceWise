import 'api_service.dart';
import 'logger_service.dart';

/// Réponse d'un message de chat IA.
class AiChatReply {
  final String reply;
  final int? conversationId;
  final List<String> toolCalls;
  final bool offline;
  final bool error;
  final String? intent;
  final bool? usedLlm;
  final String? provider;

  AiChatReply({
    required this.reply,
    this.conversationId,
    this.toolCalls = const [],
    this.offline = false,
    this.error = false,
    this.intent,
    this.usedLlm,
    this.provider,
  });
}

/// Page de messages (pagination serveur).
class AiConversationMessagesPage {
  final List<Map<String, dynamic>> messages;
  final bool hasMore;
  final int? nextBeforeId;

  AiConversationMessagesPage({
    required this.messages,
    required this.hasMore,
    this.nextBeforeId,
  });
}

/// Brief mensuel IA.
class AiMonthlyInsight {
  final String period;
  final String summary;
  final List<String> highlights;
  final List<String> suggestions;
  final bool isRead;

  AiMonthlyInsight({
    required this.period,
    required this.summary,
    required this.highlights,
    required this.suggestions,
    required this.isRead,
  });

  factory AiMonthlyInsight.fromJson(Map<String, dynamic> json) {
    return AiMonthlyInsight(
      period: json['period']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      highlights: ((json['highlights'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      suggestions: ((json['suggestions'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      isRead: json['is_read'] == true,
    );
  }
}

/// Résultat d'une catégorisation IA.
class AiCategorySuggestion {
  final int? categoryId;
  final String? categoryName;
  final double confidence;
  final String source; // memory | llm | heuristic | fallback

  AiCategorySuggestion({
    this.categoryId,
    this.categoryName,
    required this.confidence,
    required this.source,
  });

  factory AiCategorySuggestion.fromJson(Map<String, dynamic> json) {
    return AiCategorySuggestion(
      categoryId: json['category_id'] is int
          ? json['category_id'] as int
          : int.tryParse(json['category_id']?.toString() ?? ''),
      categoryName: json['category_name']?.toString(),
      confidence: (json['confidence'] is num)
          ? (json['confidence'] as num).toDouble()
          : double.tryParse(json['confidence']?.toString() ?? '0') ?? 0,
      source: json['source']?.toString() ?? 'unknown',
    );
  }
}

/// Service IA — wrappe les endpoints `/ai/*` du backend.
class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  final ApiService _api = ApiService();
  final LoggerService _logger = LoggerService();

  bool? _enabledCache;
  DateTime? _statusFetchedAt;

  /// Vérifie si l'IA est activée et configurée côté serveur (avec cache 5 min).
  Future<bool> isEnabled() async {
    if (_enabledCache != null &&
        _statusFetchedAt != null &&
        DateTime.now().difference(_statusFetchedAt!).inMinutes < 5) {
      return _enabledCache!;
    }
    try {
      final res = await _api.get('/ai/status');
      if (res is Map) {
        _enabledCache = (res['enabled'] == true) && (res['configured'] == true);
        _statusFetchedAt = DateTime.now();
        return _enabledCache!;
      }
    } catch (e) {
      _logger.error('AI status check failed: $e');
    }
    return false;
  }

  /// Envoie un message au coach, retourne la réponse + l'ID de conversation à réutiliser.
  Future<AiChatReply> chat({required String message, int? conversationId}) async {
    try {
      final body = <String, dynamic>{'message': message};
      if (conversationId != null) body['conversation_id'] = conversationId;

      final res = await _api.post('/ai/chat', body);
      if (res is! Map) {
        return AiChatReply(reply: 'Réponse invalide.', error: true);
      }
      if (res['_offline'] == true) {
        return AiChatReply(
          reply: "Tu es hors ligne. L'assistant a besoin d'Internet pour répondre.",
          offline: true,
          error: true,
        );
      }
      if (res['_rate_limited'] == true || res['_server_error'] == true || res['_expired'] == true) {
        return AiChatReply(
          reply: res['message']?.toString() ?? "L'assistant est indisponible.",
          error: true,
        );
      }

      return AiChatReply(
        reply: res['reply']?.toString() ?? '',
        conversationId: res['conversation_id'] is int
            ? res['conversation_id'] as int
            : int.tryParse(res['conversation_id']?.toString() ?? ''),
        toolCalls: ((res['tool_calls'] as List?) ?? const [])
            .map((e) => (e is Map ? (e['name']?.toString() ?? '') : e.toString()))
            .where((s) => s.isNotEmpty)
            .toList(),
        intent: res['intent']?.toString(),
        usedLlm: res['used_llm'] is bool ? res['used_llm'] as bool : null,
        provider: res['provider']?.toString(),
      );
    } catch (e) {
      _logger.error('AiService.chat error: $e');
      return AiChatReply(
        reply: "Une erreur s'est produite. Réessaie dans un instant.",
        error: true,
      );
    }
  }

  /// Liste les conversations existantes (titre + dates).
  Future<List<Map<String, dynamic>>> listConversations() async {
    try {
      final res = await _api.get('/ai/conversations');
      if (res is Map && res['data'] is List) {
        return List<Map<String, dynamic>>.from(
          (res['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }
    } catch (e) {
      _logger.error('AiService.listConversations error: $e');
    }
    return [];
  }

  /// Récupère une page de messages (les plus récents d’abord si [beforeId] est null).
  Future<AiConversationMessagesPage> fetchConversationMessagesPage(
    int conversationId, {
    int? beforeId,
    int limit = 50,
  }) async {
    try {
      final qs = <String>['limit=$limit'];
      if (beforeId != null) qs.add('before_id=$beforeId');
      final res = await _api.get('/ai/conversations/$conversationId?${qs.join('&')}');
      if (res is! Map) {
        return AiConversationMessagesPage(messages: [], hasMore: false);
      }
      final raw = (res['messages'] as List?) ?? const [];
      final messages = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final hasMore = res['has_more'] == true;
      final next = res['next_before_id'];
      final nextBeforeId = next is int ? next : int.tryParse(next?.toString() ?? '');

      return AiConversationMessagesPage(
        messages: messages,
        hasMore: hasMore,
        nextBeforeId: nextBeforeId,
      );
    } catch (e) {
      _logger.error('AiService.fetchConversationMessagesPage error: $e');
      return AiConversationMessagesPage(messages: [], hasMore: false);
    }
  }

  /// Charge toutes les pages disponibles (plafonné) pour afficher l’historique complet.
  Future<List<Map<String, dynamic>>> loadAllConversationMessages(
    int conversationId, {
    int perPage = 50,
    int maxPages = 40,
  }) async {
    final out = <Map<String, dynamic>>[];
    int? beforeId;
    for (var i = 0; i < maxPages; i++) {
      final page = await fetchConversationMessagesPage(
        conversationId,
        beforeId: beforeId,
        limit: perPage,
      );
      if (page.messages.isEmpty) break;
      if (beforeId == null) {
        out.addAll(page.messages);
      } else {
        out.insertAll(0, page.messages);
      }
      if (!page.hasMore) break;
      beforeId = page.nextBeforeId;
      if (beforeId == null) break;
    }
    return out;
  }

  /// Récupère les messages d'une conversation (première page seulement — compat legacy).
  Future<List<Map<String, dynamic>>> getConversationMessages(int conversationId) async {
    final page = await fetchConversationMessagesPage(conversationId);
    return page.messages;
  }

  Future<bool> deleteConversation(int conversationId) async {
    try {
      final res = await _api.delete('/ai/conversations/$conversationId');
      return res is Map && res['_offline'] != true && res['_server_error'] != true;
    } catch (e) {
      _logger.error('AiService.deleteConversation error: $e');
      return false;
    }
  }

  /// Récupère ou génère le brief mensuel (par défaut le mois précédent).
  Future<AiMonthlyInsight?> getMonthlyInsight({String? period}) async {
    try {
      final endpoint = period != null && period.isNotEmpty
          ? '/ai/insights/monthly?period=$period'
          : '/ai/insights/monthly';
      final res = await _api.get(endpoint);
      if (res is Map && res['_offline'] != true && res['summary'] != null) {
        return AiMonthlyInsight.fromJson(Map<String, dynamic>.from(res));
      }
    } catch (e) {
      _logger.error('AiService.getMonthlyInsight error: $e');
    }
    return null;
  }

  Future<void> markInsightRead({String? period}) async {
    try {
      await _api.post('/ai/insights/monthly/read', {
        'period': ?period,
      });
    } catch (e) {
      _logger.error('AiService.markInsightRead error: $e');
    }
  }

  /// Demande une suggestion de catégorie pour une description.
  Future<AiCategorySuggestion?> suggestCategory({
    required String description,
    String? type,
  }) async {
    try {
      final res = await _api.post('/ai/categorize', {
        'description': description,
        'type': ?type,
      });
      if (res is Map && res['_offline'] != true && res['_server_error'] != true) {
        return AiCategorySuggestion.fromJson(Map<String, dynamic>.from(res));
      }
    } catch (e) {
      _logger.error('AiService.suggestCategory error: $e');
    }
    return null;
  }

  /// Apprend d'une correction de catégorie faite par l'utilisateur.
  Future<void> learnCorrection({
    required String description,
    required int categoryId,
  }) async {
    try {
      await _api.post('/ai/categorize/learn', {
        'description': description,
        'category_id': categoryId,
      });
    } catch (e) {
      _logger.error('AiService.learnCorrection error: $e');
    }
  }
}
