import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import '../services/api_service.dart';
import '../theme.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final _api = ApiService();
  List<dynamic> _recommendations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _api.get('/recommendations');
    if (mounted) {
      setState(() {
        _loading = false;
        if (result is Map && result.containsKey('data')) {
          _recommendations = result['data'] as List;
        } else if (result is List) {
          _recommendations = result;
        } else {
          _error = result?['message'] ?? 'Erreur';
        }
      });
    }
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'alert':
        return AppTheme.error;
      case 'warning':
        return Colors.orange;
      case 'suggestion':
        return AppTheme.tertiary;
      case 'info':
        return AppTheme.onSurfaceVariant;
      default:
        return AppTheme.tertiary;
    }
  }

  IconData _getTypeIcon(String? type) {
    switch (type) {
      case 'alert':
        return Icons.warning;
      case 'warning':
        return Icons.report_problem;
      case 'suggestion':
        return Icons.lightbulb;
      case 'info':
        return Icons.info;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommandations financières'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _error != null
                  ? ListView(
                      children: [
                        const SizedBox(height: 100),
                        const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                        const SizedBox(height: 12),
                        Center(child: Text(_error!, style: const TextStyle(color: AppTheme.error))),
                      ],
                    )
                  : _recommendations.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 100),
                            Icon(Icons.lightbulb_outline, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                            const SizedBox(height: 16),
                            Center(child: Text('Aucune recommandation pour le moment', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                            const SizedBox(height: 8),
                            Center(child: Text('Continuez à utiliser l\'app pour recevoir des conseils', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _recommendations.length,
                          itemBuilder: (_, i) {
                            final recommendation = _recommendations[i];
                            final type = recommendation['type'] ?? 'info';
                            final color = _getTypeColor(type);
                            final delayMs = (60 * i).clamp(0, 500);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: AppTheme.softShadow,
                                border: Border.all(color: color.withValues(alpha: 0.15)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(_getTypeIcon(type), color: color, size: 22),
                                    ),
                                    const Gap(14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            recommendation['message'] ?? 'Recommandation',
                                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                                          ),
                                          if (recommendation['category'] != null) ...[
                                            const Gap(6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: color.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                recommendation['category'],
                                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: color),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                                .animate()
                                .fadeIn(delay: Duration(milliseconds: delayMs), duration: 300.ms)
                                .slideX(begin: 0.03, end: 0, delay: Duration(milliseconds: delayMs), duration: 300.ms);
                          },
                        ),
            ),
    );
  }
}
