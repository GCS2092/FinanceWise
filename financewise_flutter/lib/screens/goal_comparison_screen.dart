import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import 'dart:math';
import '../theme.dart';

class GoalComparisonScreen extends StatefulWidget {
  final List<dynamic> goals;
  const GoalComparisonScreen({super.key, required this.goals});

  @override
  State<GoalComparisonScreen> createState() => _GoalComparisonScreenState();
}

class _GoalComparisonScreenState extends State<GoalComparisonScreen> {
  String _chartType = 'bar'; // bar, pie, line

  @override
  Widget build(BuildContext context) {
    final activeGoals = widget.goals.where((g) => g['status'] != 'completed').toList();
    final completedGoals = widget.goals.where((g) => g['status'] == 'completed').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparaison des objectifs'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.bar_chart),
            onSelected: (value) {
              setState(() => _chartType = value);
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'bar', child: Text('Barres')),
              const PopupMenuItem(value: 'pie', child: Text('Circulaire')),
              const PopupMenuItem(value: 'line', child: Text('Ligne')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Graphique principal
            _buildMainChart(activeGoals),
            const Gap(24),
            // Statistiques globales
            _buildGlobalStats(activeGoals, completedGoals),
            const Gap(24),
            // Détails par objectif
            _buildGoalDetails(activeGoals),
          ],
        ),
      ),
    );
  }

  Widget _buildMainChart(List<dynamic> goals) {
    if (goals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.softShadow,
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.bar_chart, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
              const Gap(16),
              Text('Aucun objectif actif', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    switch (_chartType) {
      case 'bar':
        return _buildBarChart(goals);
      case 'pie':
        return _buildPieChart(goals);
      case 'line':
        return _buildLineChart(goals);
      default:
        return _buildBarChart(goals);
    }
  }

  Widget _buildBarChart(List<dynamic> goals) {
    final maxAmount = goals.fold<double>(
      0,
      (max, g) {
        final targetAmount = g['target_amount'];
        final amount = targetAmount is num ? targetAmount.toDouble() : double.tryParse(targetAmount.toString()) ?? 0;
        return amount > max ? amount : max;
      },
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Progression par objectif', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
          const Gap(20),
          ...goals.map((goal) {
            final targetAmount = goal['target_amount'];
            final currentAmount = goal['current_amount'];
            final target = targetAmount is num ? targetAmount.toDouble() : double.tryParse(targetAmount.toString()) ?? 0;
            final current = currentAmount is num ? currentAmount.toDouble() : double.tryParse(currentAmount.toString()) ?? 0;
            final progress = target > 0 ? (current / target) * 100 : 0;
            final name = goal['name'] ?? 'Objectif';
            final color = _getGoalColor(goal);

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13)),
                      Text('${progress.toStringAsFixed(0)}%', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: color)),
                    ],
                  ),
                  const Gap(8),
                  Stack(
                    children: [
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: (progress / 100).clamp(0, 1),
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Gap(4),
                  Text(
                    '${AppTheme.formatCurrency(current)} / ${AppTheme.formatCurrency(target)}',
                    style: GoogleFonts.inter(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPieChart(List<dynamic> goals) {
    final totalTarget = goals.fold<double>(
      0,
      (sum, g) => sum + ((g['target_amount'] as num?)?.toDouble() ?? 0),
    );

    if (totalTarget == 0) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.softShadow,
        ),
        child: const Center(child: Text('Données insuffisantes')),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Répartition par objectif', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
          const Gap(20),
          SizedBox(
            height: 200,
            child: CustomPaint(
              painter: _PieChartPainter(goals, totalTarget),
            ),
          ),
          const Gap(20),
          ...goals.map((goal) {
            final target = (goal['target_amount'] as num?)?.toDouble() ?? 0;
            final percentage = totalTarget > 0 ? (target / totalTarget) * 100 : 0;
            final color = _getGoalColor(goal);
            final name = goal['name'] ?? 'Objectif';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const Gap(8),
                  Expanded(child: Text(name, style: GoogleFonts.poppins(fontSize: 13))),
                  Text('${percentage.toStringAsFixed(1)}%', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<dynamic> goals) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Progression cumulée', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
          const Gap(20),
          SizedBox(
            height: 200,
            child: CustomPaint(
              painter: _LineChartPainter(goals),
              size: const Size(double.infinity, 200),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalStats(List<dynamic> activeGoals, List<dynamic> completedGoals) {
    final totalTarget = activeGoals.fold<double>(
      0,
      (sum, g) {
        final targetAmount = g['target_amount'];
        final amount = targetAmount is num ? targetAmount.toDouble() : double.tryParse(targetAmount.toString()) ?? 0;
        return sum + amount;
      },
    );
    final totalCurrent = activeGoals.fold<double>(
      0,
      (sum, g) {
        final currentAmount = g['current_amount'];
        final amount = currentAmount is num ? currentAmount.toDouble() : double.tryParse(currentAmount.toString()) ?? 0;
        return sum + amount;
      },
    );
    final overallProgress = totalTarget > 0 ? (totalCurrent / totalTarget) * 100 : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Statistiques globales', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const Gap(16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Épargné',
                  value: AppTheme.formatCurrency(totalCurrent),
                  icon: Icons.savings,
                ),
              ),
              const Gap(12),
              Expanded(
                child: _StatCard(
                  label: 'Cible',
                  value: AppTheme.formatCurrency(totalTarget),
                  icon: Icons.flag,
                ),
              ),
            ],
          ),
          const Gap(12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Progression',
                  value: '${overallProgress.toStringAsFixed(0)}%',
                  icon: Icons.trending_up,
                ),
              ),
              const Gap(12),
              Expanded(
                child: _StatCard(
                  label: 'Atteints',
                  value: completedGoals.length.toString(),
                  icon: Icons.check_circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalDetails(List<dynamic> goals) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Détails des objectifs', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
          const Gap(16),
          ...goals.map((goal) {
            final targetAmount = goal['target_amount'];
            final currentAmount = goal['current_amount'];
            final target = targetAmount is num ? targetAmount.toDouble() : double.tryParse(targetAmount.toString()) ?? 0;
            final current = currentAmount is num ? currentAmount.toDouble() : double.tryParse(currentAmount.toString()) ?? 0;
            final remaining = target - current;
            final progress = target > 0 ? (current / target) * 100 : 0;
            final name = goal['name'] ?? 'Objectif';
            final color = _getGoalColor(goal);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${progress.toStringAsFixed(0)}%',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                  const Gap(16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                        const Gap(4),
                        Text(
                          '${AppTheme.formatCurrency(current)} / ${AppTheme.formatCurrency(target)}',
                          style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppTheme.formatCurrency(remaining),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: remaining <= 0 ? AppTheme.primary : Colors.orange),
                      ),
                      Text(
                        'reste',
                        style: GoogleFonts.inter(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _getGoalColor(dynamic goal) {
    final status = goal['status'];
    if (status == 'completed') return AppTheme.primary;
    if (status == 'in_progress') return AppTheme.tertiary;
    return Colors.orange;
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const Gap(4),
          Text(value, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontSize: 10)),
        ],
      ),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<dynamic> goals;
  final double total;

  _PieChartPainter(this.goals, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    double startAngle = -pi / 2;

    for (final goal in goals) {
      final targetAmount = goal['target_amount'];
      final target = targetAmount is num ? targetAmount.toDouble() : double.tryParse(targetAmount.toString()) ?? 0;
      final percentage = total > 0 ? target / total : 0;
      final sweepAngle = (percentage * 2 * pi).toDouble();
      final color = _getGoalColor(goal);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }

    // Cercle central pour effet donut
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.6, centerPaint);
  }

  Color _getGoalColor(dynamic goal) {
    final status = goal['status'];
    if (status == 'completed') return AppTheme.primary;
    if (status == 'in_progress') return AppTheme.tertiary;
    return Colors.orange;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _LineChartPainter extends CustomPainter {
  final List<dynamic> goals;

  _LineChartPainter(this.goals);

  @override
  void paint(Canvas canvas, Size size) {
    if (goals.isEmpty) return;

    final padding = 40.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;

    // Trouver le maximum
    final maxAmount = goals.fold<double>(
      0,
      (max, g) {
        final targetAmount = g['target_amount'];
        final amount = targetAmount is num ? targetAmount.toDouble() : double.tryParse(targetAmount.toString()) ?? 0;
        return amount > max ? amount : max;
      },
    );

    if (maxAmount == 0) return;

    // Dessiner les axes
    final axisPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;

    // Axe Y
    canvas.drawLine(
      Offset(padding, padding),
      Offset(padding, size.height - padding),
      axisPaint,
    );

    // Axe X
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(size.width - padding, size.height - padding),
      axisPaint,
    );

    // Dessiner les barres
    final barWidth = chartWidth / goals.length - 8;
    final goalColors = [
      AppTheme.primary,
      AppTheme.tertiary,
      Colors.orange,
      Colors.purple,
      Colors.blue,
    ];

    for (int i = 0; i < goals.length; i++) {
      for (final goal in goals) {
        final targetAmount = goal['target_amount'];
        final currentAmount = goal['current_amount'];
        final target = targetAmount is num ? targetAmount.toDouble() : double.tryParse(targetAmount.toString()) ?? 0;
        final current = currentAmount is num ? currentAmount.toDouble() : double.tryParse(currentAmount.toString()) ?? 0;
        final currentHeight = (current / maxAmount) * chartHeight;
        final targetHeight = (target / maxAmount) * chartHeight;

        final x = padding + i * (chartWidth / goals.length) + 4;
        final yCurrent = size.height - padding - currentHeight;
        final yTarget = size.height - padding - targetHeight;

      // Barre actuelle
      final currentPaint = Paint()
        ..color = goalColors[i % goalColors.length]
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTWH(x, yCurrent, barWidth, currentHeight),
        currentPaint,
      );

      // Ligne de cible
      final targetPaint = Paint()
        ..color = Colors.grey.shade400
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(x, yTarget),
        Offset(x + barWidth, yTarget),
        targetPaint,
      );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
