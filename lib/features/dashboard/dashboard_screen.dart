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

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: profileAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.indigo),
          ),
          error: (_, __) => const Center(child: Text('Failed to load profile')),
          data: (profile) {
            if (profile == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "We couldn't load your profile.",
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => ref.invalidate(profileProvider),
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await SupabaseService.signOut();
                        if (context.mounted) context.go('/login');
                      },
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              color: AppColors.indigo,
              backgroundColor: AppColors.card,
              onRefresh: () => ref.refresh(lecturerSessionsProvider.future),
              child: CustomScrollView(
                slivers: [
                  // ── App Bar ──────────────────────────────────────────────
                  SliverAppBar(
                    floating: true,
                    backgroundColor: AppColors.darkBg.withValues(alpha: 0.95),
                    elevation: 0,
                    title: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.auto_awesome,
                              color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'VoxClass',
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      IconButton(
                        onPressed: () => context.go('/polish'),
                        icon: const Icon(Icons.auto_fix_high_outlined,
                            color: AppColors.textMuted, size: 22),
                        tooltip: 'Polish Mode',
                      ),
                      // Avatar
                      Padding(
                        padding: const EdgeInsets.only(right: 16, left: 4),
                        child: GestureDetector(
                          onTap: () async {
                            await SupabaseService.signOut();
                            if (context.mounted) context.go('/login');
                          },
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.indigo, AppColors.purple],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                profile.fullName.isNotEmpty
                                    ? profile.fullName[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // ── Greeting ──────────────────────────────────────
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Good ${_timeOfDay()},',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    profile.fullName.split(' ').first,
                                    style: GoogleFonts.inter(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                      letterSpacing: -0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: profile.isLecturer
                                    ? AppColors.purple.withValues(alpha: 0.12)
                                    : AppColors.indigo.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(
                                  color: profile.isLecturer
                                      ? AppColors.purple.withValues(alpha: 0.3)
                                      : AppColors.indigo.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                profile.isLecturer ? '🏫 Lecturer' : '📖 Student',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: profile.isLecturer
                                      ? AppColors.purpleLight
                                      : AppColors.indigoLight,
                                ),
                              ),
                            ),
                          ],
                        ).animate().fadeIn().slideY(begin: 0.15),

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
                  backgroundColor: AppColors.indigo,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  label: Text('New Class',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  icon: const Icon(Icons.add, size: 20),
                ).animate().slideY(begin: 2, delay: 400.ms)
              : null,
          orElse: () => null,
        ),
      ),
    );
  }

  String _timeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}

// ─── Lecturer Dashboard ───────────────────────────────────────────────────────

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
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppColors.indigo)),
      error: (_, __) => const Text('Could not load sessions'),
      data: (sessions) {
        final typed = sessions.cast<SessionModel>();
        final active = typed.where((s) => s.isActive).length;
        final ended = typed.where((s) => !s.isActive).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Quick Actions ───────────────────────────────────────────
            Text(
              'Quick Actions',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 0.3,
              ),
            ).animate().fadeIn(delay: 80.ms),
            const SizedBox(height: 10),
            Row(
              children: [
                _QuickActionCard(
                  icon: Icons.sensors,
                  label: 'Start\nClass',
                  gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                  onTap: () => context.go('/class/create'),
                ),
                const SizedBox(width: 10),
                _QuickActionCard(
                  icon: Icons.auto_fix_high_outlined,
                  label: 'Polish\nText',
                  gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
                  onTap: () => context.go('/polish'),
                ),
                const SizedBox(width: 10),
                _QuickActionCard(
                  icon: Icons.bar_chart_outlined,
                  label: 'Analytics',
                  gradient: const LinearGradient(
                      colors: [Color(0xFF0D9488), Color(0xFF3B82F6)]),
                  onTap: () {
                    if (typed.isNotEmpty) {
                      context.go('/class/summary/${typed.first.id}');
                    }
                  },
                ),
              ],
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

            const SizedBox(height: 24),

            // ── Stats row ───────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Total Sessions',
                    value: '${sessions.length}',
                    icon: Icons.school_outlined,
                    color: AppColors.indigo,
                    animDelay: 120,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Live Now',
                    value: '$active',
                    icon: Icons.sensors,
                    color: AppColors.green,
                    animDelay: 160,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Completed',
                    value: '$ended',
                    icon: Icons.check_circle_outline,
                    color: AppColors.purple,
                    animDelay: 200,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Session DNA card (3+ sessions) ──────────────────────────
            if (typed.length >= 3) ...[
              _DnaCard(
                loading: _loadingDna,
                insight: _dnaInsight,
                onRun: () => _runSessionDna(typed),
              ).animate().fadeIn(delay: 220.ms).slideY(begin: 0.15),
              const SizedBox(height: 16),
            ],

            // ── AI Polish feature card ───────────────────────────────────
            _FeatureCard(
              title: 'AI Text Polish',
              subtitle: 'Soften feedback, strengthen essays, polish academic writing',
              emoji: '✨',
              color: AppColors.purple,
              onTap: () => context.go('/polish'),
            ).animate().fadeIn(delay: 240.ms).slideY(begin: 0.15),

            const SizedBox(height: 28),

            // ── Sessions list ───────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Sessions',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (typed.isNotEmpty)
                  Text(
                    '${typed.length} total',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
              ],
            ).animate().fadeIn(delay: 260.ms),
            const SizedBox(height: 12),

            if (sessions.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Text('📭', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    Text(
                      'No sessions yet',
                      style: GoogleFonts.inter(
                          color: AppColors.textMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap "New Class" to start your first session',
                      style: GoogleFonts.inter(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms)
            else
              ...typed.asMap().entries.map(
                (entry) => SessionCard(
                  session: entry.value,
                  onTap: () => entry.value.isActive
                      ? context.go('/class/live/${entry.value.id}')
                      : context.go('/class/summary/${entry.value.id}'),
                ).animate().fadeIn(delay: Duration(milliseconds: 280 + entry.key * 60))
                    .slideX(begin: -0.05),
              ),
          ],
        );
      },
    );
  }
}

// ─── Student Dashboard ────────────────────────────────────────────────────────

class _StudentDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Quick Actions ─────────────────────────────────────────────────
        Text(
          'Quick Actions',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 0.3,
          ),
        ).animate().fadeIn(delay: 80.ms),
        const SizedBox(height: 10),
        Row(
          children: [
            _QuickActionCard(
              icon: Icons.login_outlined,
              label: 'Join\nClass',
              gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
              onTap: () => context.go('/class/join'),
            ),
            const SizedBox(width: 10),
            _QuickActionCard(
              icon: Icons.auto_fix_high_outlined,
              label: 'Polish\nText',
              gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
              onTap: () => context.go('/polish'),
            ),
          ],
        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

        const SizedBox(height: 24),

        _FeatureCard(
          title: 'Join a Class',
          subtitle: 'Enter the 6-digit code from your lecturer to join a live session',
          emoji: '🎓',
          color: AppColors.indigo,
          onTap: () => context.go('/class/join'),
        ).animate().fadeIn(delay: 130.ms).slideY(begin: 0.15),
        const SizedBox(height: 12),
        _FeatureCard(
          title: 'AI Text Polish',
          subtitle: 'Polish your essays, soften feedback, improve your academic writing',
          emoji: '✨',
          color: AppColors.purple,
          onTap: () => context.go('/polish'),
        ).animate().fadeIn(delay: 160.ms).slideY(begin: 0.15),
        const SizedBox(height: 28),

        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Classes Joined',
                value: '—',
                icon: Icons.school_outlined,
                color: AppColors.indigo,
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
                animDelay: 240,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Quick Action Card ────────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── DNA Card ─────────────────────────────────────────────────────────────────

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
        color: AppColors.indigo.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.indigo.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.indigo.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                    child: Text('🧬', style: TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Session DNA',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  Text(
                    'AI pattern analysis across all your sessions',
                    style:
                        GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (insight != null) ...[
            Text(
              insight!,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.6),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: loading ? null : onRun,
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Re-analyse'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.indigoLight,
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
                  backgroundColor: AppColors.indigo.withValues(alpha: 0.12),
                  foregroundColor: AppColors.indigoLight,
                  elevation: 0,
                  side: BorderSide(color: AppColors.indigo.withValues(alpha: 0.3)),
                ),
                icon: loading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.indigoLight))
                    : const Icon(Icons.biotech_outlined, size: 16),
                label: Text(
                    loading ? 'Analysing patterns...' : 'Analyse My Teaching DNA'),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Feature Card ─────────────────────────────────────────────────────────────

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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.22), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textMuted, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios, color: color.withValues(alpha: 0.6), size: 14),
          ],
        ),
      ),
    );
  }
}
