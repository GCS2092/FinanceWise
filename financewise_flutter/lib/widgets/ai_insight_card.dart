import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import '../services/ai_service.dart';
import '../theme.dart';
import '../screens/assistant_screen.dart';

/// Carte "Brief du mois" affichée sur le Dashboard.
/// Charge automatiquement le brief mensuel depuis l'IA si disponible,
/// reste invisible sinon (pas d'erreur).
class AiInsightCard extends StatefulWidget {
  const AiInsightCard({super.key});

  @override
  State<AiInsightCard> createState() => _AiInsightCardState();
}

class _AiInsightCardState extends State<AiInsightCard> {
  final AiService _ai = AiService();
  AiMonthlyInsight? _insight;
  bool _loading = true;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _ai.isEnabled();
    if (!enabled) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final insight = await _ai.getMonthlyInsight();
    if (!mounted) return;
    setState(() {
      _insight = insight;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _insight == null || _insight!.summary.isEmpty) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final i = _insight!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.08),
            cs.tertiary.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                ),
                const Gap(10),
                Text(
                  'Brief du mois',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    i.period,
                    style: GoogleFonts.inter(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const Gap(12),
            Text(
              i.summary,
              style: GoogleFonts.inter(fontSize: 13.5, height: 1.45, color: cs.onSurface),
              maxLines: _expanded ? null : 3,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (_expanded) ...[
              if (i.highlights.isNotEmpty) ...[
                const Gap(12),
                ...i.highlights.map((h) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.circle, size: 6, color: cs.primary),
                          const Gap(8),
                          Expanded(
                            child: Text(h, style: GoogleFonts.inter(fontSize: 12.5, color: cs.onSurfaceVariant)),
                          ),
                        ],
                      ),
                    )),
              ],
              if (i.suggestions.isNotEmpty) ...[
                const Gap(8),
                Text('Suggestions',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                const Gap(4),
                ...i.suggestions.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline_rounded, size: 14, color: cs.tertiary),
                          const Gap(8),
                          Expanded(
                            child: Text(s, style: GoogleFonts.inter(fontSize: 12.5, color: cs.onSurfaceVariant)),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
            const Gap(8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18),
                  label: Text(_expanded ? 'Réduire' : 'Voir détails'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AssistantScreen()),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Demander'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
