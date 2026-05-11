import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

class MoodDonutChart extends StatelessWidget {
  final int green;
  final int yellow;
  final int red;

  const MoodDonutChart({
    super.key,
    required this.green,
    required this.yellow,
    required this.red,
  });

  int get total => green + yellow + red;

  @override
  Widget build(BuildContext context) {
    if (total == 0) {
      return _EmptyChart();
    }
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 70,
              sections: [
                if (green > 0)
                  PieChartSectionData(
                    value: green.toDouble(),
                    color: AppColors.green,
                    radius: 28,
                    title: '',
                  ),
                if (yellow > 0)
                  PieChartSectionData(
                    value: yellow.toDouble(),
                    color: AppColors.amber,
                    radius: 28,
                    title: '',
                  ),
                if (red > 0)
                  PieChartSectionData(
                    value: red.toDouble(),
                    color: AppColors.red,
                    radius: 28,
                    title: '',
                  ),
              ],
            ),
            swapAnimationDuration: const Duration(milliseconds: 600),
            swapAnimationCurve: Curves.easeInOut,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$total',
                style: GoogleFonts.inter(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'reactions',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 0,
              centerSpaceRadius: 70,
              sections: [
                PieChartSectionData(
                  value: 1,
                  color: AppColors.border,
                  radius: 28,
                  title: '',
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Waiting',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted),
              ),
              Text(
                'for reactions',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MoodLegend extends StatelessWidget {
  final int green;
  final int yellow;
  final int red;

  const MoodLegend({
    super.key,
    required this.green,
    required this.yellow,
    required this.red,
  });

  int get total => green + yellow + red;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(color: AppColors.green, emoji: '🟢', label: 'I get it', count: green, total: total),
        const SizedBox(width: 16),
        _LegendItem(color: AppColors.amber, emoji: '🟡', label: 'Slow down', count: yellow, total: total),
        const SizedBox(width: 16),
        _LegendItem(color: AppColors.red, emoji: '🔴', label: 'Lost', count: red, total: total),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String emoji;
  final String label;
  final int count;
  final int total;

  const _LegendItem({
    required this.color,
    required this.emoji,
    required this.label,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total * 100).round() : 0;
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          '$count ($pct%)',
          style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w700, color: color),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
