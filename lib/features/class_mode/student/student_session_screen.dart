import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/session_provider.dart';
import '../../../services/supabase_service.dart';
import '../widgets/question_card.dart';

class StudentSessionScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const StudentSessionScreen({super.key, required this.sessionId});

  @override
  ConsumerState<StudentSessionScreen> createState() => _StudentSessionScreenState();
}

class _StudentSessionScreenState extends ConsumerState<StudentSessionScreen> {
  String? _currentReaction;
  bool _submitting = false;
  bool _submittingQuestion = false;
  String? _studentName;
  final _questionController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uri = Uri.parse(GoRouterState.of(context).uri.toString());
    _studentName = uri.queryParameters['name'] ?? 'Anonymous';
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _react(String type) async {
    if (_submitting) return;
    setState(() { _submitting = true; _currentReaction = type; });
    try {
      final user = ref.read(authStateProvider).asData?.value;
      await SupabaseService.addReaction(
        sessionId: widget.sessionId,
        type: type,
        studentId: user?.id,
        studentName: _studentName ?? 'Anonymous',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitAnonQuestion() async {
    final text = _questionController.text.trim();
    if (text.isEmpty) return;
    setState(() => _submittingQuestion = true);
    try {
      await SupabaseService.submitAnonQuestion(
        sessionId: widget.sessionId,
        questionText: text,
      );
      _questionController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Question sent anonymously!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submittingQuestion = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionProvider(widget.sessionId));
    final reactionsAsync = ref.watch(reactionsStreamProvider(widget.sessionId));
    final questionsAsync = ref.watch(pushedQuestionsStreamProvider(widget.sessionId));

    return sessionAsync.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator(color: AppColors.indigo))),
      error: (_, __) => Scaffold(
          body: Center(child: Text('Could not load session',
              style: GoogleFonts.inter(color: AppColors.textMuted)))),
      data: (session) {
        if (session == null || !session.isActive) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(gradient: AppColors.bgGradient),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🏁', style: TextStyle(fontSize: 52)),
                    const SizedBox(height: 16),
                    Text('Session ended',
                        style: GoogleFonts.inter(
                            fontSize: 22, fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    Text('Thanks for attending!',
                        style: GoogleFonts.inter(color: AppColors.textMuted)),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: () => context.go('/dashboard'),
                      child: const Text('Back to Dashboard'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final reactions = reactionsAsync.asData?.value ?? [];
        final questions = questionsAsync.asData?.value ?? [];
        final total = reactions.length;
        final green = reactions.where((r) => r.isGreen).length;
        final yellow = reactions.where((r) => r.isYellow).length;
        final red = reactions.where((r) => r.isRed).length;

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(gradient: AppColors.bgGradient),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => context.go('/dashboard'),
                          icon: const Icon(Icons.arrow_back,
                              color: AppColors.textSecondary),
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(session.title,
                                  style: GoogleFonts.inter(
                                      fontSize: 15, fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary)),
                              Row(
                                children: [
                                  Container(
                                    width: 6, height: 6,
                                    decoration: const BoxDecoration(
                                        color: AppColors.green,
                                        shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 4),
                                  Text('LIVE',
                                      style: GoogleFonts.inter(
                                          fontSize: 10, color: AppColors.green,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(width: 8),
                                  Text('Hey, $_studentName',
                                      style: GoogleFonts.inter(
                                          fontSize: 10, color: AppColors.textMuted)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Session code
                    Center(
                      child: Text('Session Code',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.textMuted)),
                    ),
                    Center(
                      child: Text(session.code,
                          style: GoogleFonts.inter(
                              fontSize: 30, fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary, letterSpacing: 6)),
                    ),
                    const SizedBox(height: 32),

                    // "How are you feeling?"
                    Center(
                      child: Text('How are you feeling?',
                          style: GoogleFonts.inter(
                              fontSize: 18, fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                    ).animate().fadeIn(),
                    const SizedBox(height: 20),

                    // Vertical reaction buttons
                    _ReactionBtn(
                      label: 'Got it',
                      icon: Icons.check_circle_outline,
                      color: AppColors.green,
                      bgColor: const Color(0xFF0D2E1A),
                      selected: _currentReaction == AppConstants.reactionGreen,
                      onTap: () => _react(AppConstants.reactionGreen),
                    ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.2),
                    const SizedBox(height: 12),
                    _ReactionBtn(
                      label: 'Unsure',
                      icon: Icons.help_outline,
                      color: AppColors.amber,
                      bgColor: const Color(0xFF2A1E00),
                      selected: _currentReaction == AppConstants.reactionYellow,
                      onTap: () => _react(AppConstants.reactionYellow),
                    ).animate().fadeIn(delay: 140.ms).slideY(begin: 0.2),
                    const SizedBox(height: 12),
                    _ReactionBtn(
                      label: 'Confused',
                      icon: Icons.error_outline,
                      color: AppColors.red,
                      bgColor: const Color(0xFF2A0A0A),
                      selected: _currentReaction == AppConstants.reactionRed,
                      onTap: () => _react(AppConstants.reactionRed),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

                    const SizedBox(height: 28),

                    // Class Mood bar
                    if (total > 0) ...[
                      _MoodBar(green: green, yellow: yellow, red: red, total: total)
                          .animate().fadeIn(delay: 260.ms),
                      const SizedBox(height: 20),
                    ],

                    // Anonymous question
                    _AnonQuestionBox(
                      controller: _questionController,
                      submitting: _submittingQuestion,
                      onSubmit: _submitAnonQuestion,
                    ).animate().fadeIn(delay: 300.ms),

                    // Slides
                    // (kept minimal — students see slides via lecturer push)

                    // Questions from lecturer
                    if (questions.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Text('❓', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text('Questions from your lecturer',
                              style: GoogleFonts.inter(
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                        ],
                      ).animate().fadeIn(delay: 340.ms),
                      const SizedBox(height: 10),
                      ...questions.map((q) {
                        final user = ref.read(authStateProvider).asData?.value;
                        return QuestionCard(
                          question: q,
                          canRespond: true,
                          onRespond: (text) => SupabaseService.submitResponse(
                            questionId: q.id,
                            responseText: text,
                            studentId: user?.id,
                            studentName: _studentName ?? 'Anonymous',
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Vertical Reaction Button ─────────────────────────────────────────────────

class _ReactionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final bool selected;
  final VoidCallback onTap;

  const _ReactionBtn({
    required this.label, required this.icon, required this.color,
    required this.bgColor, required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 62,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.35),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

// ── Class Mood Bar ───────────────────────────────────────────────────────────

class _MoodBar extends StatelessWidget {
  final int green, yellow, red, total;
  const _MoodBar({required this.green, required this.yellow,
      required this.red, required this.total});

  @override
  Widget build(BuildContext context) {
    final gf = green / total;
    final yf = yellow / total;
    final rf = red / total;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Class Mood',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textMuted,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(flex: (gf * 100).round(),
                      child: Container(color: AppColors.green)),
                  if (yf > 0)
                    Expanded(flex: (yf * 100).round(),
                        child: Container(color: AppColors.amber)),
                  if (rf > 0)
                    Expanded(flex: (rf * 100).round(),
                        child: Container(color: AppColors.red)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Anonymous Question Box ───────────────────────────────────────────────────

class _AnonQuestionBox extends StatelessWidget {
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

  const _AnonQuestionBox({
    required this.controller, required this.submitting, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ask anonymously',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textMuted,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Type your question...',
                    hintStyle: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.cardGlass,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                      borderSide: const BorderSide(color: AppColors.indigo),
                    ),
                  ),
                  onSubmitted: (_) => onSubmit(),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: submitting ? null : onSubmit,
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.indigo.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.indigo.withValues(alpha: 0.4)),
                  ),
                  child: submitting
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.indigo))
                      : const Icon(Icons.send_outlined,
                          color: AppColors.indigo, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
