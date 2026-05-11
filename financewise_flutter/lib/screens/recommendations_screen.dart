import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../theme.dart';
import '../widgets/skeleton_loader.dart';
import 'assistant_screen.dart';

/// Écran Recommandations — consomme `/recommendations` du backend
/// (analyses heuristiques) et propose un raccourci vers l'assistant IA
/// pour des questions plus précises.
class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final ApiService _api = ApiService();
  final LoggerService _logger = LoggerService();
  List<Map<String, dynamic>> _recos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.get('/recommendations');
      if (res is Map && res['data'] is List) {
        _recos = List<Map<String, dynamic>>.from(
          (res['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
      } else {
        _recos = [];
      }
    } catch (e) {
      _logger.error('Recommendations load error: $e');
      _error = 'Impossible de charger les recommandations.';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Recommandations', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: List.generate(4, (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: SkeletonLoader(height: 80),
                    )),
              )
            : _error != null
                ? _buildError(cs)
                : _recos.isEmpty
                    ? _buildEmpty(cs)
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildAssistantBanner(cs),
                          const Gap(16),
                          ..._recos.map((r) => _buildRecoCard(r, cs)),
                        ],
                      ),
      ),
    );
  }

  Widget _buildAssistantBanner(ColorScheme cs) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AssistantScreen()));
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pose ta question à l\'assistant',
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('Analyse personnalisée par IA',
                      style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoCard(Map<String, dynamic> r, ColorScheme cs) {
    final type = (r['type'] ?? 'info').toString();
    final message = (r['message'] ?? '').toString();
    final (icon, color) = _styleForType(type, cs);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const Gap(12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(fontSize: 13.5, height: 1.4, color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _styleForType(String type, ColorScheme cs) {
    switch (type) {
      case 'alert':
      case 'danger':
        return (Icons.error_outline_rounded, cs.error);
      case 'warning':
        return (Icons.warning_amber_rounded, AppTheme.warning);
      case 'suggestion':
        return (Icons.lightbulb_outline_rounded, AppTheme.tertiary);
      case 'success':
        return (Icons.check_circle_outline_rounded, AppTheme.success);
      default:
        return (Icons.info_outline_rounded, cs.primary);
    }
  }

  Widget _buildEmpty(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const Gap(60),
        Icon(Icons.lightbulb_outline_rounded, size: 64, color: cs.outline),
        const Gap(16),
        Text(
          'Aucune recommandation pour le moment',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const Gap(8),
        Text(
          'Continue d\'enregistrer tes transactions, des conseils personnalisés apparaîtront ici.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 13, color: cs.onSurfaceVariant),
        ),
        const Gap(24),
        FilledButton.icon(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AssistantScreen()));
          },
          icon: const Icon(Icons.auto_awesome_rounded, size: 16),
          label: const Text('Demander à l\'assistant'),
        ),
      ],
    );
  }

  Widget _buildError(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const Gap(60),
        Icon(Icons.cloud_off_rounded, size: 64, color: cs.outline),
        const Gap(16),
        Text(_error ?? 'Erreur',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        const Gap(16),
        FilledButton(onPressed: _load, child: const Text('Réessayer')),
      ],
    );
  }
}
