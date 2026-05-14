import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/reaction_model.dart';

class ComprehensionTimelineChart extends StatelessWidget {
  final List<ReactionModel> reactions;
  final DateTime sessionStart;

  const ComprehensionTimelineChart({
    super.key,
    required this.reactions,
    required this.sessionStart,
  });

  List<FlSpot> _buildConfusionSpots() {
    if (reactions.length < 3) return [];

    final sorted = [...reactions]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final totalMinutes = sorted.last.createdAt.difference(sessionStart).inMinutes + 1;
    if (totalMinutes < 1) return [];

    final bucketSize = totalMinutes <= 6 ? 1 : 2;
    final numBuckets = (totalMinutes / bucketSize).ceil().clamp(2, 40);

    final spots = <FlSpot>[];
    for (int i = 0; i < numBuckets; i++) {
      final start = sessionStart.add(Duration(minutes: i * bucketSize));
      final end = sessionStart.add(Duration(minutes: (i + 1) * bucketSize));
      final inBucket = sorted
          .where((r) => !r.createdAt.isBefore(start) && r.createdAt.isBefore(end))
          .toList();
      if (inBucket.isEmpty) continue;
      final total = inBucket.length.toDouble();
      final confusedCount = inBucket.where((r) => r.isRed).length;
      final x = (i * bucketSize).toDouble();
      spots.add(FlSpot(x, confusedCount / total * 100));
    }

    return spots.length >= 2 ? spots : [];
  }

  @override
  Widget build(BuildContext context) {
    final spots = _buildConfusionSpots();

    if (spots.isEmpty) {
      return Container(
        height: 90,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(
            '📈  Confusion timeline builds as students react',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
      );
    }

    final maxX = spots.last.x + 1;
    final xInterval = maxX <= 10 ? 2.0 : (maxX / 5).ceilToDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                color: AppColors.red, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text('Confusion Timeline',
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.textMuted)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: 155,
          padding: const EdgeInsets.fromLTRB(4, 12, 12, 4),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  color: AppColors.red,
                  isCurved: true,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.red.withValues(alpha: 0.18),
                        AppColors.red.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ],
              minX: 0,
              maxX: maxX,
              minY: 0,
              maxY: 100,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 50,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: AppColors.border, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 20,
                    interval: xInterval,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}m',
                        style: GoogleFonts.inter(
                            fontSize: 9, color: AppColors.textMuted)),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 50,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                        style: GoogleFonts.inter(
                            fontSize: 9, color: AppColors.textMuted)),
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.cardElevated,
                  tooltipRoundedRadius: 10,
                  getTooltipItems: (touchedSpots) => touchedSpots
                      .map((s) => LineTooltipItem(
                            'confusion: ${s.y.toStringAsFixed(0)}%',
                            GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
