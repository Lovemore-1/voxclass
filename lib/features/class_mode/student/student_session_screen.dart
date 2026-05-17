import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/question_model.dart';
import '../../../models/slide_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/session_provider.dart';
import '../../../services/gemini_service.dart';
import '../../../services/supabase_service.dart';
import '../widgets/question_card.dart';
import '../widgets/file_viewer.dart';

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
  bool _loadingAiHelp = false;
  String? _studentName;
  String? _lastSlideId; // track slide changes to reset reaction
  final _questionController = TextEditingController();
  final _gemini = GeminiService();

  // Track which questions have already been seen (to animate new ones in)
  final Set<String> _seenQuestionIds = {};

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

  Future<void> _react(String type, {String? slideId}) async {
    if (_submitting) return;
    debugPrint('[VoxClass][Student] Sending reaction: $type | slideId=$slideId');
    setState(() {
      _submitting = true;
      _currentReaction = type;
    });
    try {
      final user = ref.read(authStateProvider).asData?.value;
      await SupabaseService.addReaction(
        sessionId: widget.sessionId,
        type: type,
        slideId: slideId,
        studentId: user?.id,
        studentName: _studentName ?? 'Anonymous',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send reaction: $e')));
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

  Future<void> _showAnswerSheet(
      String questionText, String sessionTitle, String? subject) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AnswerSheet(
        question: questionText,
        sessionTitle: sessionTitle,
        subject: subject,
        gemini: _gemini,
      ),
    );
  }

  Future<void> _showAiHelp(String sessionTitle, String? subject,
      {String? slideUrl, String? slideFileName}) async {
    setState(() => _loadingAiHelp = true);
    try {
      // Use text-only explanations to conserve Gemini quota.
      // Vision (sending slide bytes) uses 10x more quota and is reserved
      // for the lecturer's question-generation feature.
      debugPrint('[VoxClass][Student] Requesting AI re-explanations (text-only) for "$sessionTitle"');
      final options = await _gemini.generateReexplanations(
        topic: sessionTitle,
        subject: subject,
      );
      if (!mounted) return;
      setState(() => _loadingAiHelp = false);
      await showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.card,
        isScrollControlled: true,
        enableDrag: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => _AiHelpSheet(
          topic: sessionTitle,
          options: options,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _loadingAiHelp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionProvider(widget.sessionId));
    final liveStateAsync = ref.watch(sessionStateStreamProvider(widget.sessionId));
    final reactionsAsync = ref.watch(reactionsStreamProvider(widget.sessionId));
    final questionsAsync = ref.watch(pushedQuestionsStreamProvider(widget.sessionId));
    final slidesAsync = ref.watch(slidesStreamProvider(widget.sessionId));

    final liveSession = liveStateAsync.asData?.value;

    return sessionAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.indigo))),
      error: (_, __) => Scaffold(
        body: Center(child: Text('Could not load session',
            style: GoogleFonts.inter(color: AppColors.textMuted)))),
      data: (initialSession) {
        final session = liveSession ?? initialSession;

        // ── Session ended ────────────────────────────────────────────────
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
                        style: GoogleFonts.inter(fontSize: 22,
                            fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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

        final allReactions = reactionsAsync.asData?.value ?? [];
        final questions = questionsAsync.asData?.value ?? [];
        final slides = slidesAsync.asData?.value ?? [];

        // ── Reset reaction when lecturer moves to a new slide ────────────
        final currentSlideId = session.currentSlideId;
        debugPrint('[VoxClass][Student] sessionState → currentSlideId=$currentSlideId status=${session.status}');
        if (currentSlideId != _lastSlideId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _lastSlideId = currentSlideId;
                _currentReaction = null;
                _seenQuestionIds.clear();
              });
              debugPrint('[VoxClass][Student] Slide changed → $currentSlideId | reactions + questions reset');
            }
          });
        }

        // ── Presenting mode ──────────────────────────────────────────────
        if (currentSlideId != null) {
          SlideModel? currentSlide;
          int slideIndex = 0;
          for (int i = 0; i < slides.length; i++) {
            if (slides[i].id == currentSlideId) {
              currentSlide = slides[i];
              slideIndex = i + 1;
              break;
            }
          }
          // Only count reactions for the CURRENT slide
          final slideReactions = allReactions
              .where((r) => r.slideId == currentSlideId)
              .toList();
          // Show questions that match the current slide, OR have no slideId (session-wide questions)
          final slideQuestions = questions
              .where((q) => q.slideId == currentSlideId || q.slideId == null)
              .toList();
          return _PresentingView(
            sessionTitle: session.title,
            subject: session.subject,
            slide: currentSlide,
            slideIndex: slideIndex,
            totalSlides: slides.length,
            currentPage: session.currentPage,
            pointerVisible: session.pointerVisible,
            pointerX: session.pointerX,
            pointerY: session.pointerY,
            currentReaction: _currentReaction,
            submitting: _submitting,
            loadingAiHelp: _loadingAiHelp,
            questions: slideQuestions,
            reactions: slideReactions,
            studentName: _studentName ?? 'Anonymous',
            onReact: (type) => _react(type, slideId: currentSlideId),
            onAiHelp: () => _showAiHelp(session.title, session.subject),
            onAnswered: (q) => _showAnswerSheet(q, session.title, session.subject),
            seenIds: _seenQuestionIds,
            onMarkSeen: (id) => setState(() => _seenQuestionIds.add(id)),
          );
        }

        // ── Waiting / interactive mode ───────────────────────────────────
        return _WaitingView(
          session: session,
          reactions: allReactions,
          questions: questions,
          studentName: _studentName ?? 'Anonymous',
          currentReaction: _currentReaction,
          submitting: _submitting,
          submittingQuestion: _submittingQuestion,
          loadingAiHelp: _loadingAiHelp,
          questionController: _questionController,
          onReact: (type) => _react(type),
          onSubmitQuestion: _submitAnonQuestion,
          onAiHelp: () => _showAiHelp(session.title, session.subject),
          onAnswered: (q) => _showAnswerSheet(q, session.title, session.subject),
          seenIds: _seenQuestionIds,
          onMarkSeen: (id) => setState(() => _seenQuestionIds.add(id)),
          ref: ref,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Waiting / Interactive View
// ─────────────────────────────────────────────────────────────────────────────

class _WaitingView extends StatelessWidget {
  final dynamic session;
  final List reactions;
  final List<QuestionModel> questions;
  final String studentName;
  final String? currentReaction;
  final bool submitting, submittingQuestion, loadingAiHelp;
  final TextEditingController questionController;
  final Future<void> Function(String) onReact;
  final VoidCallback onSubmitQuestion;
  final VoidCallback onAiHelp;
  final void Function(String questionText) onAnswered;
  final Set<String> seenIds;
  final void Function(String) onMarkSeen;
  final WidgetRef ref;

  const _WaitingView({
    required this.session,
    required this.reactions,
    required this.questions,
    required this.studentName,
    required this.currentReaction,
    required this.submitting,
    required this.submittingQuestion,
    required this.loadingAiHelp,
    required this.questionController,
    required this.onReact,
    required this.onSubmitQuestion,
    required this.onAiHelp,
    required this.onAnswered,
    required this.seenIds,
    required this.onMarkSeen,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final total = reactions.length;
    final green = reactions.where((r) => r.isGreen).length;
    final yellow = reactions.where((r) => r.isYellow).length;
    final red = reactions.where((r) => r.isRed).length;
    final hasReacted = currentReaction != null;
    final isConfused = currentReaction == AppConstants.reactionRed;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go('/dashboard'),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textMuted, size: 18),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(session.title,
                              style: GoogleFonts.inter(fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis),
                          Row(children: [
                            Container(width: 6, height: 6,
                                decoration: const BoxDecoration(
                                    color: AppColors.green, shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Text('LIVE',
                                style: GoogleFonts.inter(fontSize: 10,
                                    color: AppColors.green, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            Text('Hey, $studentName',
                                style: GoogleFonts.inter(
                                    fontSize: 10, color: AppColors.textMuted)),
                          ]),
                        ],
                      ),
                    ),
                    // Session code chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.indigo.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.indigo.withValues(alpha: 0.3)),
                      ),
                      child: Text(session.code,
                          style: GoogleFonts.inter(fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.indigoLight, letterSpacing: 2)),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── New question notification ──────────────────────────
                      ...questions.where((q) => !seenIds.contains(q.id)).map((q) {
                        return _NewQuestionBanner(
                          question: q,
                          onDismiss: () => onMarkSeen(q.id),
                          onAnswered: () => onAnswered(q.questionText),
                          onRespond: (text) {
                            final user = ref.read(authStateProvider).asData?.value;
                            return SupabaseService.submitResponse(
                              questionId: q.id,
                              responseText: text,
                              studentId: user?.id,
                              studentName: studentName,
                            );
                          },
                        ).animate().slideY(begin: -0.3).fadeIn();
                      }),

                      // ── Reaction section ──────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Text('💬', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Text('How are you feeling?',
                                  style: GoogleFonts.inter(fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary)),
                            ]),
                            const SizedBox(height: 14),

                            if (!hasReacted) ...[
                              // Big reaction buttons before first reaction
                              _BigReactionBtn(
                                emoji: '🟢', label: 'Got it',
                                sublabel: 'I understand',
                                color: AppColors.green,
                                onTap: () => onReact(AppConstants.reactionGreen),
                              ),
                              const SizedBox(height: 8),
                              _BigReactionBtn(
                                emoji: '🟡', label: 'Unsure',
                                sublabel: 'Need a moment',
                                color: AppColors.amber,
                                onTap: () => onReact(AppConstants.reactionYellow),
                              ),
                              const SizedBox(height: 8),
                              _BigReactionBtn(
                                emoji: '🔴', label: 'Confused',
                                sublabel: 'Lost — please help',
                                color: AppColors.red,
                                onTap: () => onReact(AppConstants.reactionRed),
                              ),
                            ] else ...[
                              // Compact confirmed state
                              Row(children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _reactionColor(currentReaction!)
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: _reactionColor(currentReaction!)
                                              .withValues(alpha: 0.4)),
                                    ),
                                    child: Row(children: [
                                      Text(_reactionEmoji(currentReaction!),
                                          style: const TextStyle(fontSize: 18)),
                                      const SizedBox(width: 8),
                                      Text(
                                        'You reacted: ${_reactionLabel(currentReaction!)}',
                                        style: GoogleFonts.inter(fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: _reactionColor(currentReaction!)),
                                      ),
                                    ]),
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 10),
                              // Small change buttons
                              Row(children: [
                                Text('Change: ',
                                    style: GoogleFonts.inter(fontSize: 11,
                                        color: AppColors.textMuted)),
                                const SizedBox(width: 4),
                                _SmallReact(emoji: '🟢', selected: currentReaction == AppConstants.reactionGreen,
                                    onTap: () => onReact(AppConstants.reactionGreen)),
                                const SizedBox(width: 6),
                                _SmallReact(emoji: '🟡', selected: currentReaction == AppConstants.reactionYellow,
                                    onTap: () => onReact(AppConstants.reactionYellow)),
                                const SizedBox(width: 6),
                                _SmallReact(emoji: '🔴', selected: currentReaction == AppConstants.reactionRed,
                                    onTap: () => onReact(AppConstants.reactionRed)),
                              ]),
                            ],

                            // AI Help for confused students
                            if (isConfused) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: loadingAiHelp ? null : onAiHelp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.purple.withValues(alpha: 0.15),
                                    foregroundColor: AppColors.purpleLight,
                                    side: BorderSide(
                                        color: AppColors.purple.withValues(alpha: 0.4)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  icon: loadingAiHelp
                                      ? const SizedBox(width: 16, height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: AppColors.purpleLight))
                                      : const Text('🤖', style: TextStyle(fontSize: 16)),
                                  label: Text(loadingAiHelp
                                      ? 'Getting explanations...'
                                      : 'Get AI Explanation',
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600)),
                                ),
                              ).animate().fadeIn().slideY(begin: 0.2),
                            ],
                          ],
                        ),
                      ).animate().fadeIn(),

                      // ── Class mood snapshot ───────────────────────────────
                      if (total > 0) ...[
                        const SizedBox(height: 12),
                        _MoodSnapshot(green: green, yellow: yellow, red: red, total: total)
                            .animate().fadeIn(delay: 80.ms),
                      ],

                      // ── Past questions (seen) ─────────────────────────────
                      if (questions.where((q) => seenIds.contains(q.id)).isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('Questions from your lecturer',
                            style: GoogleFonts.inter(fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted)),
                        const SizedBox(height: 8),
                        ...questions.where((q) => seenIds.contains(q.id)).map((q) {
                          final user = ref.read(authStateProvider).asData?.value;
                          return QuestionCard(
                            question: q,
                            canRespond: true,
                            onRespond: (text) => SupabaseService.submitResponse(
                              questionId: q.id,
                              responseText: text,
                              studentId: user?.id,
                              studentName: studentName,
                            ),
                          );
                        }),
                      ],

                      // ── Anonymous Q&A ─────────────────────────────────────
                      const SizedBox(height: 16),
                      _AnonBox(
                        controller: questionController,
                        submitting: submittingQuestion,
                        onSubmit: onSubmitQuestion,
                      ).animate().fadeIn(delay: 120.ms),

                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          '💡 Tip: Reactions are anonymous to other students',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Presenting View (slide is active)
// ─────────────────────────────────────────────────────────────────────────────

class _PresentingView extends StatelessWidget {
  final String sessionTitle;
  final String? subject;
  final SlideModel? slide;
  final int slideIndex, totalSlides;
  final int currentPage;
  final bool pointerVisible;
  final double? pointerX, pointerY;
  final String? currentReaction;
  final bool submitting, loadingAiHelp;
  final List<QuestionModel> questions;
  final List reactions; // per-slide reactions for mood display
  final String studentName;
  final Future<void> Function(String) onReact;
  final VoidCallback onAiHelp;
  final void Function(String questionText) onAnswered;
  final Set<String> seenIds;
  final void Function(String) onMarkSeen;

  const _PresentingView({
    required this.sessionTitle,
    required this.subject,
    required this.slide,
    required this.slideIndex,
    required this.totalSlides,
    this.currentPage = 1,
    required this.pointerVisible,
    required this.pointerX,
    required this.pointerY,
    required this.currentReaction,
    required this.submitting,
    required this.loadingAiHelp,
    required this.questions,
    required this.reactions,
    required this.studentName,
    required this.onReact,
    required this.onAiHelp,
    required this.onAnswered,
    required this.seenIds,
    required this.onMarkSeen,
  });

  @override
  Widget build(BuildContext context) {
    final hasReacted = currentReaction != null;
    final isConfused = currentReaction == AppConstants.reactionRed;
    final newQuestions = questions.where((q) => !seenIds.contains(q.id)).toList();
    final green = reactions.where((r) => (r as dynamic).isGreen).length;
    final yellow = reactions.where((r) => (r as dynamic).isYellow).length;
    final red = reactions.where((r) => (r as dynamic).isRed).length;
    final total = reactions.length;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // ── Top bar ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 16, color: AppColors.textSecondary),
                        onPressed: () => context.go('/dashboard'),
                        tooltip: 'Leave session',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                      Container(width: 8, height: 8,
                          decoration: const BoxDecoration(
                              color: AppColors.green, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('LIVE',
                          style: GoogleFonts.inter(fontSize: 10,
                              color: AppColors.green, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(sessionTitle,
                            style: GoogleFonts.inter(fontSize: 12,
                                color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (totalSlides > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text('Slide $slideIndex of $totalSlides',
                              style: GoogleFonts.inter(fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ),

                // ── Slide area ───────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        final ext = slide?.fileName.split('.').last.toLowerCase() ?? '';
                        final isImage = const {'png', 'jpg', 'jpeg', 'webp'}.contains(ext);

                        return ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            color: AppColors.card,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (slide == null)
                                  Center(child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(color: AppColors.indigo),
                                      const SizedBox(height: 12),
                                      Text('Loading slide...',
                                          style: GoogleFonts.inter(
                                              color: AppColors.textMuted, fontSize: 12)),
                                    ],
                                  ))
                                else if (isImage)
                                  Image.network(slide!.fileUrl, fit: BoxFit.contain)
                                else
                                  FileViewer(
                                    fileUrl: slide!.fileUrl,
                                    fileName: slide!.fileName,
                                    currentPage: currentPage,
                                  ),
                                // invisible placeholder for pointer (kept for Stack alignment)
                                if (false)
                                  Center(child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(height: 10),
                                        Text(slide?.fileName ?? '',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(fontSize: 13,
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 6),
                                        Text('',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(fontSize: 11,
                                                color: AppColors.textMuted)),
                                      ],
                                    ),
                                  )),

                                // ── Laser pointer ──────────────────────
                                if (pointerVisible && pointerX != null && pointerY != null)
                                  Positioned(
                                    left: pointerX!.clamp(0.0, 1.0) * constraints.maxWidth - 14,
                                    top: pointerY!.clamp(0.0, 1.0) * constraints.maxHeight - 14,
                                    child: IgnorePointer(
                                      child: Container(
                                        width: 28, height: 28,
                                        decoration: BoxDecoration(
                                          color: AppColors.red.withValues(alpha: 0.55),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                          boxShadow: [BoxShadow(
                                            color: AppColors.red.withValues(alpha: 0.5),
                                            blurRadius: 12, spreadRadius: 2,
                                          )],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ── Bottom reaction strip ────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  decoration: BoxDecoration(
                    color: AppColors.card.withValues(alpha: 0.95),
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: hasReacted
                      ? Row(children: [
                          Text(_reactionEmoji(currentReaction!),
                              style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Text('You: ${_reactionLabel(currentReaction!)}',
                              style: GoogleFonts.inter(fontSize: 12,
                                  color: _reactionColor(currentReaction!),
                                  fontWeight: FontWeight.w600)),
                          const Spacer(),
                          // Compact change buttons
                          _SmallReact(emoji: '🟢',
                              selected: currentReaction == AppConstants.reactionGreen,
                              onTap: () => onReact(AppConstants.reactionGreen)),
                          const SizedBox(width: 6),
                          _SmallReact(emoji: '🟡',
                              selected: currentReaction == AppConstants.reactionYellow,
                              onTap: () => onReact(AppConstants.reactionYellow)),
                          const SizedBox(width: 6),
                          _SmallReact(emoji: '🔴',
                              selected: currentReaction == AppConstants.reactionRed,
                              onTap: () => onReact(AppConstants.reactionRed)),
                          if (isConfused) ...[
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: loadingAiHelp ? null : onAiHelp,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.purple.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: AppColors.purple.withValues(alpha: 0.4)),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  loadingAiHelp
                                      ? const SizedBox(width: 12, height: 12,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.purpleLight))
                                      : const Text('🤖', style: TextStyle(fontSize: 12)),
                                  const SizedBox(width: 4),
                                  Text('AI Help',
                                      style: GoogleFonts.inter(fontSize: 11,
                                          color: AppColors.purpleLight,
                                          fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ).animate(onPlay: (c) => c.repeat(reverse: true))
                                .fadeIn(duration: 600.ms),
                          ],
                        ])
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text('React:',
                                style: GoogleFonts.inter(fontSize: 12,
                                    color: AppColors.textMuted)),
                            _MiniReactBtn(
                              emoji: '🟢', label: 'Got it',
                              color: AppColors.green,
                              onTap: () => onReact(AppConstants.reactionGreen),
                            ),
                            _MiniReactBtn(
                              emoji: '🟡', label: 'Unsure',
                              color: AppColors.amber,
                              onTap: () => onReact(AppConstants.reactionYellow),
                            ),
                            _MiniReactBtn(
                              emoji: '🔴', label: 'Confused',
                              color: AppColors.red,
                              onTap: () => onReact(AppConstants.reactionRed),
                            ),
                          ],
                        ),
                ),
              ],
            ),

            // ── New question notification strip (bottom, non-blocking) ───
            if (newQuestions.isNotEmpty)
              Positioned(
                bottom: 100,
                left: 12,
                right: 12,
                child: newQuestions.take(1).map((q) =>
                  GestureDetector(
                    onTap: () {
                      onMarkSeen(q.id);
                      onAnswered(q.questionText);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.indigo.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Row(children: [
                        Expanded(child: Text(q.questionText,
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.white,
                                fontWeight: FontWeight.w500),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.lime.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Answer', style: GoogleFonts.inter(
                              fontSize: 10, color: AppColors.lime,
                              fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => onMarkSeen(q.id),
                          child: const Icon(Icons.close_rounded, size: 14, color: Colors.white54)),
                      ]),
                    ),
                  ).animate().slideY(begin: 0.5).fadeIn(),
                ).first,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper functions
// ─────────────────────────────────────────────────────────────────────────────

Color _reactionColor(String type) {
  switch (type) {
    case 'green': return AppColors.green;
    case 'yellow': return AppColors.amber;
    case 'red': return AppColors.red;
    default: return AppColors.textMuted;
  }
}

String _reactionEmoji(String type) {
  switch (type) {
    case 'green': return '🟢';
    case 'yellow': return '🟡';
    case 'red': return '🔴';
    default: return '⚪';
  }
}

String _reactionLabel(String type) {
  switch (type) {
    case 'green': return 'Got it';
    case 'yellow': return 'Unsure';
    case 'red': return 'Confused';
    default: return '';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _BigReactionBtn extends StatelessWidget {
  final String emoji, label, sublabel;
  final Color color;
  final VoidCallback onTap;
  const _BigReactionBtn({required this.emoji, required this.label,
      required this.sublabel, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            Text(sublabel,
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
          ]),
          const Spacer(),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
        ]),
      ),
    );
  }
}

class _SmallReact extends StatelessWidget {
  final String emoji;
  final bool selected;
  final VoidCallback onTap;
  const _SmallReact({required this.emoji, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.indigo.withValues(alpha: 0.15)
              : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.indigo : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 16))),
      ),
    );
  }
}

class _MiniReactBtn extends StatelessWidget {
  final String emoji, label;
  final Color color;
  final VoidCallback onTap;
  const _MiniReactBtn({required this.emoji, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.inter(fontSize: 12,
              color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _MoodSnapshot extends StatelessWidget {
  final int green, yellow, red, total;
  const _MoodSnapshot({required this.green, required this.yellow,
      required this.red, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Text('Class vibe:',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: SizedBox(
              height: 8,
              child: Row(children: [
                Expanded(flex: green.clamp(0, 100),
                    child: Container(color: AppColors.green)),
                if (yellow > 0)
                  Expanded(flex: yellow.clamp(0, 100),
                      child: Container(color: AppColors.amber)),
                if (red > 0)
                  Expanded(flex: red.clamp(0, 100),
                      child: Container(color: AppColors.red)),
                if (green == 0 && yellow == 0 && red == 0)
                  Expanded(flex: 1, child: Container(color: AppColors.border)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('$total reactions',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
      ]),
    );
  }
}

class _NewQuestionBanner extends StatelessWidget {
  final QuestionModel question;
  final VoidCallback onDismiss;
  final VoidCallback onAnswered;
  final Future<void> Function(String) onRespond;
  const _NewQuestionBanner({required this.question,
      required this.onDismiss, required this.onAnswered, required this.onRespond});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.indigo.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.indigo.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('New question from your lecturer',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.indigoLight,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded, size: 16,
                color: AppColors.textMuted),
          ),
        ]),
        const SizedBox(height: 8),
        Text(question.questionText,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary,
                height: 1.4)),
        const SizedBox(height: 10),
        QuestionCard(
          question: question,
          canRespond: true,
          onRespond: (text) async {
            await onRespond(text);
            // After submitting, offer to see the answer
            onAnswered();
          },
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onAnswered,
            icon: const Icon(Icons.lightbulb_outline_rounded, size: 14),
            label: const Text('See AI Answer'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.lime,
              side: BorderSide(color: AppColors.lime.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 8),
              textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ]),
    );
  }
}

class _QuestionPopup extends StatelessWidget {
  final QuestionModel question;
  final VoidCallback onDismiss;
  final VoidCallback onSeeAnswer;
  const _QuestionPopup({required this.question, required this.onDismiss, required this.onSeeAnswer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.indigo.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(question.questionText,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white,
                    fontWeight: FontWeight.w500),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded, size: 16, color: Colors.white54)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: onSeeAnswer,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.lime.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.lime.withValues(alpha: 0.5)),
                ),
                child: Center(child: Text('💡 See Answer',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.lime,
                        fontWeight: FontWeight.w600))),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _AnonBox extends StatelessWidget {
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;
  const _AnonBox({required this.controller,
      required this.submitting, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🙈', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text('Ask anonymously',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted,
                  fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'What are you confused about?',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.cardGlass,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                border: Border.all(color: AppColors.indigo.withValues(alpha: 0.4)),
              ),
              child: submitting
                  ? const Padding(padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2,
                          color: AppColors.indigo))
                  : const Icon(Icons.send_rounded, color: AppColors.indigo, size: 18),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ── AI Help Bottom Sheet ──────────────────────────────────────────────────────

class _AiHelpSheet extends StatelessWidget {
  final String topic;
  final List<Map<String, String>> options;
  const _AiHelpSheet({required this.topic, required this.options});

  static const _icons = {'analogy': '💡', 'steps': '📋', 'example': '🎯'};

  @override
  Widget build(BuildContext context) {
    // PointerInterceptor prevents the PDF.js iframe underneath from stealing
    // pointer events (web only; no-op on other platforms).
    // Plain SingleChildScrollView replaces DraggableScrollableSheet so that
    // drag-to-select text in SelectableText is never confused with sheet resizing.
    return PointerInterceptor(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // drag handle (visual only)
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              const Text('🤖', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('AI Explanations',
                      style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  Text(topic, style: GoogleFonts.inter(fontSize: 12,
                      color: AppColors.textMuted), overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
            const SizedBox(height: 4),
            Text('Pick the explanation style that clicks for you:',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 16),
            ...options.map((opt) {
              final type = opt['type'] ?? '';
              final label = opt['label'] ?? '';
              final text = opt['text'] ?? '';
              final icon = _icons[type] ?? '💡';
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(label,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700,
                            color: AppColors.purpleLight))),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.copy_outlined, size: 16,
                          color: AppColors.textMuted),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: text));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('$label copied',
                                style: GoogleFonts.inter(fontSize: 12)),
                            duration: const Duration(seconds: 1),
                            backgroundColor: AppColors.indigo,
                          ));
                        }
                      },
                    ),
                  ]),
                  const SizedBox(height: 10),
                  SelectableText(
                    text,
                    style: GoogleFonts.inter(fontSize: 13,
                        color: AppColors.textSecondary, height: 1.6),
                  ),
                ]),
              ).animate().fadeIn(
                  delay: Duration(milliseconds: options.indexOf(opt) * 80));
            }),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  side: const BorderSide(color: AppColors.border),
                ),
                child: const Text('Got it, close'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Answer Sheet — shown after student submits / taps "See Answer"
// ─────────────────────────────────────────────────────────────────────────────

class _AnswerSheet extends StatefulWidget {
  final String question;
  final String sessionTitle;
  final String? subject;
  final GeminiService gemini;
  const _AnswerSheet({required this.question, required this.sessionTitle,
      required this.subject, required this.gemini});

  @override
  State<_AnswerSheet> createState() => _AnswerSheetState();
}

class _AnswerSheetState extends State<_AnswerSheet> {
  String? _answer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ans = await widget.gemini.generateQuestionAnswer(
      questionText: widget.question,
      sessionTitle: widget.sessionTitle,
      subject: widget.subject,
    );
    if (mounted) setState(() { _answer = ans; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
     child: Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20,
          MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(children: [
            const Text('💡', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(child: Text('AI Answer', style: GoogleFonts.inter(fontSize: 16,
                fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
          ]),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.indigo.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.indigo.withValues(alpha: 0.2)),
            ),
            child: Text(widget.question,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic, height: 1.4)),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: AppColors.lime)),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lime.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.lime.withValues(alpha: 0.3)),
              ),
              child: Text(_answer ?? '',
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary,
                      height: 1.6)),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it ✓'),
            ),
          ),
        ],
      ),
     ),
    );
  }
}
