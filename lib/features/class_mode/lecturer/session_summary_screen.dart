import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/session_provider.dart';
import '../../../services/gemini_service.dart';
import '../widgets/comprehension_timeline_chart.dart';
import '../widgets/mood_donut_chart.dart';

class SessionSummaryScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const SessionSummaryScreen({super.key, required this.sessionId});

  @override
  ConsumerState<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends ConsumerState<SessionSummaryScreen> {
  final _gemini = GeminiService();
  String? _insight;
  bool _loadingInsight = false;

  Future<void> _loadInsight(String title, int g, int y, int r) async {
    setState(() => _loadingInsight = true);
    try {
      final text = await _gemini.generateSessionInsights(
        sessionTitle: title, greenCount: g, yellowCount: y, redCount: r);
      setState(() => _insight = text);
    } catch (_) {
      setState(() => _insight = 'Could not generate insight.');
    } finally {
      setState(() => _loadingInsight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionProvider(widget.sessionId));
    final reactionsAsync = ref.watch(reactionsStreamProvider(widget.sessionId));
    final questionsAsync = ref.watch(questionsStreamProvider(widget.sessionId));

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/dashboard'),
          ),
          title: const Text('Session Summary'),
        ),
        body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.lime)),
        error: (_, __) => const Center(child: Text('Session not found')),
        data: (session) {
          if (session == null) return const Center(child: Text('Not found'));
          final reactions = reactionsAsync.asData?.value ?? [];
          final questions = questionsAsync.asData?.value ?? [];
          final green = reactions.where((r) => r.isGreen).length;
          final yellow = reactions.where((r) => r.isYellow).length;
          final red = reactions.where((r) => r.isRed).length;
          final df = DateFormat('d MMM y, h:mm a');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.title,
                    style: GoogleFonts.inter(
                        fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary))
                    .animate().fadeIn(),
                const SizedBox(height: 4),
                Text(df.format(session.createdAt),
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))
                    .animate().fadeIn(delay: 50.ms),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryStatCard(
                        label: 'Reactions',
                        value: '${reactions.length}',
                        icon: Icons.bar_chart_outlined,
                        color: AppColors.lime,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryStatCard(
                        label: 'Questions',
                        value: '${questions.length}',
                        icon: Icons.quiz_outlined,
                        color: AppColors.purple,
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 24),
                SizedBox(
                  height: 240,
                  child: MoodDonutChart(green: green, yellow: yellow, red: red),
                ).animate().fadeIn(delay: 150.ms),
                const SizedBox(height: 12),
                MoodLegend(green: green, yellow: yellow, red: red).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 24),
                ComprehensionTimelineChart(
                  reactions: reactions,
                  sessionStart: session.createdAt,
                ).animate().fadeIn(delay: 220.ms),
                const SizedBox(height: 28),
                // AI Insight
                if (_insight != null) ...[
                  _InsightCard(text: _insight!).animate().fadeIn(),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loadingInsight
                          ? null
                          : () => _loadInsight(session.title, green, yellow, red),
                      icon: _loadingInsight
                          ? const SizedBox(
                              height: 16, width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.auto_awesome_outlined),
                      label: Text(_loadingInsight ? 'Analysing...' : 'Get AI Insight'),
                    ),
                  ).animate().fadeIn(delay: 250.ms),
                ],
                const SizedBox(height: 28),
                if (questions.isNotEmpty) ...[
                  Text('Questions Asked',
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))
                      .animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 10),
                  ...questions.map((q) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(q.questionText,
                            style: GoogleFonts.inter(
                                fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
                      ).animate().fadeIn(delay: 350.ms).slideX(begin: -0.1)),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/class/create'),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Start Another Session'),
                  ),
                ).animate().fadeIn(delay: 400.ms),
              ],
            ),
          );
        },
      ),
    ),
    );
  }
}

class _SummaryStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryStatCard({
    required this.label, required this.value,
    required this.icon, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text(label,
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String text;
  const _InsightCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.lime.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lime.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🤖', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gemini Insight',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.lime)),
                const SizedBox(height: 6),
                Text(text,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
