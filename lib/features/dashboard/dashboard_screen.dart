import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../models/session_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/gemini_service.dart';
import '../../services/supabase_service.dart';
import 'widgets/stat_card.dart';
import 'widgets/session_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final sessionsAsync = ref.watch(lecturerSessionsProvider);

    return Scaffold(
      body: profileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.lime),
        ),
        error: (_, __) => const Center(child: Text('Failed to load profile')),
        data: (profile) {
          if (profile == null) {
            return Center(
              child: TextButton(
                onPressed: () async {
                  await SupabaseService.signOut();
                  if (context.mounted) context.go('/login');
                },
                child: const Text('Session expired. Sign in again.'),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.lime,
            backgroundColor: AppColors.card,
            onRefresh: () => ref.refresh(lecturerSessionsProvider.future),
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  floating: true,
                  backgroundColor: AppColors.darkBg,
                  title: Text(
                    'VoxClass',
                    style: GoogleFonts.inter(
                      color: AppColors.lime,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  actions: [
                    IconButton(
                      onPressed: () => context.go('/polish'),
                      icon: const Icon(Icons.auto_fix_high_outlined),
                      tooltip: 'Polish Mode',
                    ),
                    IconButton(
                      onPressed: () async {
                        await SupabaseService.signOut();
                        if (context.mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.logout_outlined),
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Greeting
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Hey, ',
                              style: GoogleFonts.inter(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            TextSpan(
                              text: profile.fullName.split(' ').first,
                              style: GoogleFonts.inter(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppColors.lime,
                              ),
                            ),
                            const TextSpan(text: ' 👋'),
                          ],
                        ),
                      ).animate().fadeIn().slideY(begin: 0.2),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: profile.isLecturer
                              ? AppColors.purple.withOpacity(0.15)
                              : AppColors.lime.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          profile.isLecturer ? '🏫 Lecturer' : '📖 Student',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: profile.isLecturer
                                ? AppColors.purpleLight
                                : AppColors.lime,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ).animate().fadeIn(delay: 50.ms),
                      const SizedBox(height: 28),

                      if (profile.isLecturer) ...[
                        _LecturerDashboard(sessionsAsync: sessionsAsync),
                      ] else ...[
                        _StudentDashboard(),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: profileAsync.maybeWhen(
        data: (profile) => profile?.isLecturer == true
            ? FloatingActionButton.extended(
                onPressed: () => context.go('/class/create'),
                label: const Text('Start Class'),
                icon: const Icon(Icons.add),
              ).animate().slideY(begin: 2, delay: 300.ms)
            : null,
        orElse: () => null,
      ),
    );
  }
}

class _LecturerDashboard extends ConsumerStatefulWidget {
  final AsyncValue<List> sessionsAsync;

  const _LecturerDashboard({required this.sessionsAsync});

  @override
  ConsumerState<_LecturerDashboard> createState() => _LecturerDashboardState();
}

class _LecturerDashboardState extends ConsumerState<_LecturerDashboard> {
  final _gemini = GeminiService();
  bool _loadingDna = false;
  String? _dnaInsight;

  Future<void> _runSessionDna(List<SessionModel> sessions) async {
    setState(() => _loadingDna = true);
    try {
      final summaries = await SupabaseService.getSessionsSummary(sessions);
      if (summaries.isEmpty) {
        setState(() => _dnaInsight =
            'No reaction data found. Make sure students use reactions during sessions.');
        return;
      }
      final insight = await _gemini.analyzeTeachingPatterns(summaries);
      setState(() => _dnaInsight = insight);
    } catch (e) {
      setState(() => _dnaInsight = 'Analysis failed: $e');
    } finally {
      if (mounted) setState(() => _loadingDna = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.sessionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.lime)),
      error: (_, __) => const Text('Could not load sessions'),
      data: (sessions) {
        final typed = sessions.cast<SessionModel>();
        final active = typed.where((s) => s.isActive).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Total Sessions',
                    value: '${sessions.length}',
                    icon: Icons.school_outlined,
                    color: AppColors.lime,
                    animDelay: 100,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Active Now',
                    value: '$active',
                    icon: Icons.sensors,
                    color: AppColors.green,
                    animDelay: 150,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Session DNA card (3+ sessions)
            if (typed.length >= 3) ...[
              _DnaCard(
                loading: _loadingDna,
                insight: _dnaInsight,
                onRun: () => _runSessionDna(typed),
              ).animate().fadeIn(delay: 170.ms).slideY(begin: 0.2),
              const SizedBox(height: 20),
            ],

            // Polish CTA
            _FeatureCard(
              title: 'AI Text Polish',
              subtitle: 'Soften feedback, strengthen essays, polish academic writing',
              emoji: '✨',
              color: AppColors.purple,
              onTap: () => context.go('/polish'),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
            const SizedBox(height: 28),
            Text(
              'Your Sessions',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ).animate().fadeIn(delay: 250.ms),
            const SizedBox(height: 12),
            if (sessions.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Text('📭', style: TextStyle(fontSize: 36)),
                    const SizedBox(height: 12),
                    Text(
                      'No sessions yet',
                      style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms)
            else
              ...typed.map(
                (s) => SessionCard(
                  session: s,
                  onTap: () => s.isActive
                      ? context.go('/class/live/${s.id}')
                      : context.go('/class/summary/${s.id}'),
                ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1),
              ),
          ],
        );
      },
    );
  }
}

class _DnaCard extends StatelessWidget {
  final bool loading;
  final String? insight;
  final VoidCallback onRun;

  const _DnaCard({required this.loading, required this.insight, required this.onRun});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.lime.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lime.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🧬', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Session DNA',
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  Text('AI pattern analysis across all your sessions',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (insight != null) ...[
            Text(insight!,
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textSecondary, height: 1.55)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: loading ? null : onRun,
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Re-analyse'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.lime,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: loading ? null : onRun,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lime.withOpacity(0.12),
                  foregroundColor: AppColors.lime,
                  side: BorderSide(color: AppColors.lime.withOpacity(0.3)),
                ),
                icon: loading
                    ? const SizedBox(
                        height: 16, width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.lime))
                    : const Icon(Icons.biotech_outlined, size: 16),
                label: Text(loading ? 'Analysing patterns...' : 'Analyse My Teaching DNA'),
              ),
            ),
        ],
      ),
    );
  }
}

class _StudentDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FeatureCard(
          title: 'Join a Class',
          subtitle: 'Enter the 6-digit code from your lecturer to join a live session',
          emoji: '🎓',
          color: AppColors.lime,
          onTap: () => context.go('/class/join'),
        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),
        const SizedBox(height: 14),
        _FeatureCard(
          title: 'AI Text Polish',
          subtitle: 'Polish your essays, soften feedback, improve your academic writing',
          emoji: '✨',
          color: AppColors.purple,
          onTap: () => context.go('/polish'),
        ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Classes Joined',
                value: '—',
                icon: Icons.school_outlined,
                color: AppColors.lime,
                animDelay: 200,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Rewrites Done',
                value: '—',
                icon: Icons.auto_fix_high_outlined,
                color: AppColors.purple,
                animDelay: 250,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emoji;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textMuted, height: 1.4),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 14),
          ],
        ),
      ),
    );
  }
}
