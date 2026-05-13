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
import '../widgets/reaction_button.dart';
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
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uri = Uri.parse(GoRouterState.of(context).uri.toString());
    _studentName = uri.queryParameters['name'] ?? 'Anonymous';
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
          const SnackBar(content: Text('✅ Question sent anonymously!')),
        );
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
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionProvider(widget.sessionId));
    final slidesAsync = ref.watch(slidesStreamProvider(widget.sessionId));
    final questionsAsync = ref.watch(pushedQuestionsStreamProvider(widget.sessionId));

    return sessionAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.lime)),
      ),
      error: (_, __) => Scaffold(
        body: Center(
          child: Text('Could not load session',
              style: GoogleFonts.inter(color: AppColors.textMuted)),
        ),
      ),
      data: (session) {
        if (session == null || !session.isActive) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/dashboard'),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏁', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text('Session ended',
                      style: GoogleFonts.inter(
                          fontSize: 20, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text('Thanks for attending!',
                      style: GoogleFonts.inter(color: AppColors.textMuted)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.go('/dashboard'),
                    child: const Text('Back to Dashboard'),
                  ),
                ],
              ),
            ),
          );
        }

        final slides = slidesAsync.asData?.value ?? [];
        final questions = questionsAsync.asData?.value ?? [];

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/dashboard'),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.title,
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                          color: AppColors.green, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text('LIVE',
                        style: GoogleFonts.inter(
                            fontSize: 10, color: AppColors.green, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Text('Hey, $_studentName',
                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reaction section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('How are you following?',
                          style: GoogleFonts.inter(
                              fontSize: 16, fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Tap anytime — your lecturer sees it live',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ReactionButton(
                              emoji: '🟢',
                              label: 'I get it',
                              color: AppColors.green,
                              selected: _currentReaction == AppConstants.reactionGreen,
                              onTap: () => _react(AppConstants.reactionGreen),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ReactionButton(
                              emoji: '🟡',
                              label: 'Slow down',
                              color: AppColors.amber,
                              selected: _currentReaction == AppConstants.reactionYellow,
                              onTap: () => _react(AppConstants.reactionYellow),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ReactionButton(
                              emoji: '🔴',
                              label: "I'm lost",
                              color: AppColors.red,
                              selected: _currentReaction == AppConstants.reactionRed,
                              onTap: () => _react(AppConstants.reactionRed),
                            ),
                          ),
                        ],
                      ),
                      if (_currentReaction != null) ...[
                        const SizedBox(height: 14),
                        Center(
                          child: Text(
                            _reactionFeedback(_currentReaction!),
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppColors.textMuted),
                            textAlign: TextAlign.center,
                          ),
                        ).animate().fadeIn(),
                      ],
                    ],
                  ),
                ).animate().fadeIn(),

                // Anonymous question box
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('💬', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text('Ask anonymously',
                              style: GoogleFonts.inter(
                                  fontSize: 14, fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Your name is never shown to the lecturer',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.textMuted)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _questionController,
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'What are you confused about?',
                                hintStyle: GoogleFonts.inter(
                                    fontSize: 13, color: AppColors.textMuted),
                                filled: true,
                                fillColor: AppColors.darkBg,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.lime),
                                ),
                              ),
                              maxLines: 2,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _submitAnonQuestion(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _submittingQuestion ? null : _submitAnonQuestion,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(12),
                              minimumSize: const Size(44, 44),
                            ),
                            child: _submittingQuestion
                                ? const SizedBox(
                                    height: 16, width: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: AppColors.darkBg))
                                : const Icon(Icons.send_outlined, size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 80.ms),

                // Slides section
                if (slides.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Slides',
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary))
                      .animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 180,
                    child: PageView.builder(
                      itemCount: slides.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            slides[i].fileUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.card,
                              child: const Center(
                                child: Icon(Icons.image_outlined, color: AppColors.textMuted),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 120.ms),
                ],

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
                  ).animate().fadeIn(delay: 150.ms),
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
        );
      },
    );
  }

  String _reactionFeedback(String type) {
    switch (type) {
      case 'green':
        return '✅ Great! Your lecturer knows you\'re following along.';
      case 'yellow':
        return '⚠️ Noted. Your lecturer will slow down soon.';
      case 'red':
        return '🔴 Hang tight. Your lecturer sees that you\'re confused and will address it.';
      default:
        return '';
    }
  }
}
