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

  List<List<FlSpot>> _buildSpots() {
    if (reactions.length < 3) return [[], [], []];

    final sorted = [...reactions]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final totalMinutes = sorted.last.createdAt.difference(sessionStart).inMinutes + 1;
    if (totalMinutes < 1) return [[], [], []];

    final bucketSize = totalMinutes <= 6 ? 1 : 2;
    final numBuckets = (totalMinutes / bucketSize).ceil().clamp(2, 40);

    final green = <FlSpot>[];
    final yellow = <FlSpot>[];
    final red = <FlSpot>[];

    for (int i = 0; i < numBuckets; i++) {
      final start = sessionStart.add(Duration(minutes: i * bucketSize));
      final end = sessionStart.add(Duration(minutes: (i + 1) * bucketSize));
      final inBucket = sorted
          .where((r) => !r.createdAt.isBefore(start) && r.createdAt.isBefore(end))
          .toList();
      if (inBucket.isEmpty) continue;

      final total = inBucket.length.toDouble();
      final x = (i * bucketSize).toDouble();
      green.add(FlSpot(x, inBucket.where((r) => r.isGreen).length / total * 100));
      yellow.add(FlSpot(x, inBucket.where((r) => r.isYellow).length / total * 100));
      red.add(FlSpot(x, inBucket.where((r) => r.isRed).length / total * 100));
    }

    if (green.length < 2 && yellow.length < 2 && red.length < 2) return [[], [], []];
    return [green, yellow, red];
  }

  @override
  Widget build(BuildContext context) {
    final spots = _buildSpots();
    final greenSpots = spots[0];
    final yellowSpots = spots[1];
    final redSpots = spots[2];

    if (greenSpots.isEmpty && yellowSpots.isEmpty && redSpots.isEmpty) {
      return Container(
        height: 90,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(
            '📈  Timeline builds as reactions come in',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
      );
    }

    final allX = [...greenSpots, ...yellowSpots, ...redSpots].map((s) => s.x);
    final maxX = allX.reduce((a, b) => a > b ? a : b) + 1;

    final bars = <LineChartBarData>[
      if (greenSpots.length >= 2)
        LineChartBarData(
          spots: greenSpots,
          color: AppColors.green,
          isCurved: true,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: AppColors.green.withOpacity(0.08)),
        ),
      if (yellowSpots.length >= 2)
        LineChartBarData(
          spots: yellowSpots,
          color: AppColors.amber,
          isCurved: true,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: AppColors.amber.withOpacity(0.08)),
        ),
      if (redSpots.length >= 2)
        LineChartBarData(
          spots: redSpots,
          color: AppColors.red,
          isCurved: true,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: AppColors.red.withOpacity(0.08)),
        ),
    ];

    final xInterval = maxX <= 10 ? 2.0 : (maxX / 5).ceilToDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Comprehension Timeline',
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
            const Spacer(),
            _Dot(color: AppColors.green, label: 'Got it'),
            const SizedBox(width: 10),
            _Dot(color: AppColors.amber, label: 'Unsure'),
            const SizedBox(width: 10),
            _Dot(color: AppColors.red, label: 'Lost'),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: 155,
          padding: const EdgeInsets.fromLTRB(4, 12, 12, 4),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: LineChart(
            LineChartData(
              lineBarsData: bars,
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
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 20,
                    interval: xInterval,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}m',
                        style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 50,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                        style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)),
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.cardElevated,
                  getTooltipItems: (spots) => spots
                      .map((s) => LineTooltipItem(
                            '${s.y.toStringAsFixed(0)}%',
                            GoogleFonts.inter(
                              fontSize: 11,
                              color: s.bar.color ?? AppColors.lime,
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

class _Dot extends StatelessWidget {
  final Color color;
  final String label;
  const _Dot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
      ],
    );
  }
}
