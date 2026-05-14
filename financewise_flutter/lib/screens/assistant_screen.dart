import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import '../services/ai_service.dart';
import '../theme.dart';

/// Écran Assistant IA — chat conversationnel avec function calling backend.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final AiService _ai = AiService();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_ChatMsg> _messages = [];

  int? _conversationId;
  bool _sending = false;
  bool _loadingStatus = true;
  bool _loadingConversation = false;
  bool _aiAvailable = false;
  List<Map<String, dynamic>> _drawerConversations = [];

  static const List<String> _suggestions = [
    "Combien j'ai dépensé ce mois ?",
    "Compare avec le mois dernier",
    "Mes 3 plus grosses dépenses",
    "Où en sont mes objectifs ?",
    "Mes budgets sont-ils respectés ?",
  ];

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refreshDrawerConversations() async {
    final list = await _ai.listConversations();
    if (!mounted) return;
    setState(() => _drawerConversations = list);
  }

  void _startNewConversation() {
    Navigator.of(context).maybePop();
    setState(() {
      _messages.clear();
      _conversationId = null;
      _loadingConversation = false;
      if (_aiAvailable) {
        _messages.add(_ChatMsg.assistant(
          "Salut ! Je suis ton assistant FinanceWise. Pose-moi une question sur tes finances ou choisis une suggestion ci-dessous.",
        ));
      } else {
        _messages.add(_ChatMsg.assistant(
          "L'assistant n'est pas configuré sur ce serveur. Demande à l'administrateur d'ajouter une clé API IA dans le fichier .env.",
        ));
      }
    });
  }

  Future<void> _loadConversationFromServer(int id) async {
    Navigator.of(context).maybePop();
    setState(() {
      _loadingConversation = true;
      _messages.clear();
      _conversationId = id;
    });
    final rows = await _ai.loadAllConversationMessages(id);
    if (!mounted) return;
    setState(() {
      _loadingConversation = false;
      _messages.clear();
      for (final m in rows) {
        final role = m['role']?.toString() ?? '';
        final c = m['content']?.toString() ?? '';
        if (role == 'user') {
          _messages.add(_ChatMsg.user(c));
        } else {
          _messages.add(_ChatMsg.assistant(c));
        }
      }
      if (_messages.isEmpty) {
        _messages.add(_ChatMsg.assistant('Cette conversation est vide.'));
      }
    });
    _scrollToBottom();
  }

  Future<void> _checkStatus() async {
    final ok = await _ai.isEnabled();
    if (!mounted) return;
    setState(() {
      _aiAvailable = ok;
      _loadingStatus = false;
      if (!ok) {
        _messages.add(_ChatMsg.assistant(
          "L'assistant n'est pas configuré sur ce serveur. Demande à l'administrateur d'ajouter une clé API IA dans le fichier .env.",
        ));
      } else {
        _messages.add(_ChatMsg.assistant(
          "Salut ! Je suis ton assistant FinanceWise. Pose-moi une question sur tes finances ou choisis une suggestion ci-dessous.",
        ));
      }
    });
  }

  Future<void> _send(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _sending || _loadingConversation) return;

    setState(() {
      _messages.add(_ChatMsg.user(msg));
      _messages.add(_ChatMsg.typing());
      _sending = true;
      _input.clear();
    });
    _scrollToBottom();

    final reply = await _ai.chat(message: msg, conversationId: _conversationId);

    if (!mounted) return;
    setState(() {
      // Retirer l'indicateur "typing"
      _messages.removeWhere((m) => m.typing);
      _messages.add(_ChatMsg.assistant(reply.reply, error: reply.error));
      _conversationId = reply.conversationId ?? _conversationId;
      _sending = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      key: _scaffoldKey,
      onDrawerChanged: (opened) {
        if (opened) _refreshDrawerConversations();
      },
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text('Conversations', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18)),
              ),
              ListTile(
                leading: const Icon(Icons.add_comment_rounded),
                title: Text('Nouvelle conversation', style: GoogleFonts.inter()),
                onTap: _startNewConversation,
              ),
              const Divider(height: 1),
              Expanded(
                child: _drawerConversations.isEmpty
                    ? Center(child: Text('Aucune conversation', style: GoogleFonts.inter(color: cs.onSurfaceVariant)))
                    : ListView.builder(
                        itemCount: _drawerConversations.length,
                        itemBuilder: (context, i) {
                          final c = _drawerConversations[i];
                          final id = c['id'] is int ? c['id'] as int : int.tryParse(c['id']?.toString() ?? '') ?? 0;
                          final title = c['title']?.toString() ?? 'Conversation';
                          return ListTile(
                            title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 14)),
                            onTap: id > 0 ? () => _loadConversationFromServer(id) : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: cs.onSurface),
          ),
          tooltip: 'Retour',
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
            ),
            const Gap(10),
            Text('Assistant', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Historique',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          if (_messages.length > 1)
            IconButton(
              tooltip: 'Nouvelle conversation',
              onPressed: (_sending || _loadingConversation) ? null : _startNewConversation,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_loadingStatus || _loadingConversation)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, i) => _buildBubble(_messages[i], cs),
            ),
          ),
          if (_aiAvailable)
            _buildSuggestions(cs),
          _buildInput(cs),
        ],
      ),
    );
  }

  Widget _buildBubble(_ChatMsg m, ColorScheme cs) {
    if (m.typing) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const _TypingDots(),
          ),
        ),
      );
    }

    final isUser = m.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
            ),
            const Gap(8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: m.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copié'), duration: Duration(seconds: 1)),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser
                      ? cs.primary
                      : (m.error ? cs.errorContainer : cs.surfaceContainerHighest),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                ),
                child: SelectableText(
                  m.content,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.4,
                    color: isUser
                        ? cs.onPrimary
                        : (m.error ? cs.onErrorContainer : cs.onSurface),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _suggestions.map((s) {
          return ActionChip(
            label: Text(s, style: GoogleFonts.inter(fontSize: 12.5)),
            onPressed: _sending || _loadingConversation ? null : () => _send(s),
            backgroundColor: cs.primaryContainer.withValues(alpha: 0.4),
            side: BorderSide(color: cs.outlineVariant),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInput(ColorScheme cs) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                enabled: _aiAvailable && !_sending && !_loadingConversation,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
                decoration: InputDecoration(
                  hintText: _aiAvailable ? 'Pose ta question...' : 'Assistant indisponible',
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const Gap(8),
            Material(
              color: (_sending || _loadingConversation) ? cs.surfaceContainerHighest : cs.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: (_aiAvailable && !_sending && !_loadingConversation) ? () => _send(_input.text) : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.send_rounded,
                    size: 18,
                    color: (_sending || _loadingConversation) ? cs.onSurfaceVariant : cs.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMsg {
  final String role; // user | assistant
  final String content;
  final bool typing;
  final bool error;

  _ChatMsg({required this.role, required this.content, this.typing = false, this.error = false});

  factory _ChatMsg.user(String s) => _ChatMsg(role: 'user', content: s);
  factory _ChatMsg.assistant(String s, {bool error = false}) =>
      _ChatMsg(role: 'assistant', content: s, error: error);
  factory _ChatMsg.typing() => _ChatMsg(role: 'assistant', content: '', typing: true);
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = ((_ctrl.value + i * 0.2) % 1.0);
            final scale = 0.7 + 0.6 * (t < 0.5 ? t * 2 : (1 - t) * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
