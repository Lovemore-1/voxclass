import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/reaction_model.dart';
import '../../../models/slide_model.dart';
import '../../../providers/session_provider.dart';
import '../../../services/gemini_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/supabase_service.dart';
import '../widgets/mood_donut_chart.dart';
import '../widgets/qr_display_widget.dart';
import '../widgets/question_card.dart';

class LiveSessionScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const LiveSessionScreen({super.key, required this.sessionId});

  @override
  ConsumerState<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends ConsumerState<LiveSessionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _gemini = GeminiService();
  bool _uploadingSlide = false;
  bool _generatingQuestions = false;
  bool _generatingClarifying = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _uploadSlide() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _uploadingSlide = true);
    try {
      final slides = ref.read(slidesStreamProvider(widget.sessionId)).asData?.value ?? [];
      final url = await StorageService.uploadSlide(
        sessionId: widget.sessionId,
        bytes: file.bytes!,
        fileName: file.name,
      );
      await SupabaseService.addSlide(
        sessionId: widget.sessionId,
        fileUrl: url,
        fileName: file.name,
        orderIndex: slides.length,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Slide uploaded!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingSlide = false);
    }
  }

  Future<void> _generateQuestionsFromSlide(SlideModel slide) async {
    setState(() => _generatingQuestions = true);
    try {
      final bytes = await StorageService.downloadSlide(slide.fileUrl);
      if (bytes == null) throw Exception('Could not download slide');
      final questions = await _gemini.generateQuestionsFromImage(bytes);
      await SupabaseService.saveQuestions(
        sessionId: widget.sessionId,
        questions: questions,
        sourceType: 'slide',
        slideId: slide.id,
      );
      _tabs.animateTo(2);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Generated ${questions.length} questions!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingQuestions = false);
    }
  }

  Future<void> _generateClarifyingQuestions(
      List<ReactionModel> reactions, String sessionTitle, String? subject) async {
    final red = reactions.where((r) => r.isRed).length;
    if (red == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No confused students detected yet.')),
      );
      return;
    }
    setState(() => _generatingClarifying = true);
    try {
      final questions = await _gemini.generateClarifyingQuestions(
        sessionTitle: sessionTitle,
        subject: subject,
        confusedCount: red,
        totalStudents: reactions.length,
      );
      await SupabaseService.saveQuestions(
        sessionId: widget.sessionId,
        questions: questions,
        sourceType: 'confused',
      );
      _tabs.animateTo(2);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Generated ${questions.length} clarifying questions!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _generatingClarifying = false);
    }
  }

  Future<void> _endSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('End Session?',
            style: GoogleFonts.inter(color: AppColors.textPrimary)),
        content: Text('This will close the session for all students.',
            style: GoogleFonts.inter(color: AppColors.textMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('End Session')),
        ],
      ),
    );
    if (confirm != true) return;
    await SupabaseService.endSession(widget.sessionId);
    if (mounted) context.go('/class/summary/${widget.sessionId}');
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionProvider(widget.sessionId));
    final reactionsAsync = ref.watch(reactionsStreamProvider(widget.sessionId));
    final slidesAsync = ref.watch(slidesStreamProvider(widget.sessionId));
    final questionsAsync = ref.watch(questionsStreamProvider(widget.sessionId));

    return sessionAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.lime)),
      ),
      error: (_, __) => const Scaffold(body: Center(child: Text('Session not found'))),
      data: (session) {
        if (session == null) return const Scaffold(body: Center(child: Text('Not found')));
        final reactions = reactionsAsync.asData?.value ?? [];
        final green = reactions.where((r) => r.isGreen).length;
        final yellow = reactions.where((r) => r.isYellow).length;
        final red = reactions.where((r) => r.isRed).length;

        return Scaffold(
          appBar: AppBar(
            leading: const BackButton(),
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
                    Text(session.code,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textMuted,
                            letterSpacing: 2)),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: _endSession,
                child: Text('End', style: GoogleFonts.inter(color: AppColors.red)),
              ),
            ],
            bottom: TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'Mood'),
                Tab(text: 'Slides'),
                Tab(text: 'Questions'),
                Tab(text: 'Confused'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              // ── Tab 1: Mood ──────────────────────────────────────────
              _MoodTab(
                green: green,
                yellow: yellow,
                red: red,
                reactions: reactions,
                code: session.code,
                sessionTitle: session.title,
              ),
              // ── Tab 2: Slides ────────────────────────────────────────
              _SlidesTab(
                slidesAsync: slidesAsync,
                uploading: _uploadingSlide,
                generating: _generatingQuestions,
                onUpload: _uploadSlide,
                onGenerateQuestions: _generateQuestionsFromSlide,
              ),
              // ── Tab 3: Questions ─────────────────────────────────────
              _QuestionsTab(questionsAsync: questionsAsync),
              // ── Tab 4: Confused ──────────────────────────────────────
              _ConfusedTab(
                reactions: reactions,
                redCount: red,
                generating: _generatingClarifying,
                onGenerate: () => _generateClarifyingQuestions(
                    reactions, session.title, session.subject),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MoodTab extends StatelessWidget {
  final int green, yellow, red;
  final List<ReactionModel> reactions;
  final String code;
  final String sessionTitle;

  const _MoodTab({
    required this.green, required this.yellow, required this.red,
    required this.reactions, required this.code, required this.sessionTitle,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(
            height: 260,
            child: MoodDonutChart(green: green, yellow: yellow, red: red),
          ).animate().fadeIn(),
          const SizedBox(height: 16),
          MoodLegend(green: green, yellow: yellow, red: red),
          const SizedBox(height: 24),
          QrDisplayWidget(code: code, sessionTitle: sessionTitle),
          const SizedBox(height: 24),
          if (reactions.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Recent Reactions',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
            ),
            const SizedBox(height: 8),
            ...reactions.take(8).map((r) => _ReactionRow(reaction: r)),
          ],
        ],
      ),
    );
  }
}

class _ReactionRow extends StatelessWidget {
  final ReactionModel reaction;
  const _ReactionRow({required this.reaction});

  @override
  Widget build(BuildContext context) {
    final emoji = reaction.isGreen ? '🟢' : reaction.isYellow ? '🟡' : '🔴';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Text(reaction.studentName,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    ).animate().fadeIn().slideX(begin: -0.1);
  }
}

class _SlidesTab extends StatelessWidget {
  final AsyncValue<List<SlideModel>> slidesAsync;
  final bool uploading;
  final bool generating;
  final VoidCallback onUpload;
  final void Function(SlideModel) onGenerateQuestions;

  const _SlidesTab({
    required this.slidesAsync, required this.uploading,
    required this.generating, required this.onUpload,
    required this.onGenerateQuestions,
  });

  @override
  Widget build(BuildContext context) {
    final slides = slidesAsync.asData?.value ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: uploading ? null : onUpload,
              icon: uploading
                  ? const SizedBox(
                      height: 16, width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_file_outlined),
              label: Text(uploading ? 'Uploading...' : 'Upload Slide (JPG/PNG)'),
            ),
          ),
          const SizedBox(height: 20),
          if (slides.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    const Text('🖼️', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    Text('Upload slides to generate AI questions',
                        style: GoogleFonts.inter(color: AppColors.textMuted),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          else
            ...slides.map((slide) => _SlideCard(
                  slide: slide,
                  generating: generating,
                  onGenerate: () => onGenerateQuestions(slide),
                )),
        ],
      ),
    );
  }
}

class _SlideCard extends StatelessWidget {
  final SlideModel slide;
  final bool generating;
  final VoidCallback onGenerate;

  const _SlideCard({required this.slide, required this.generating, required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            child: Image.network(
              slide.fileUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 180,
                color: AppColors.border,
                child: const Center(child: Icon(Icons.image_outlined, color: AppColors.textMuted)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(slide.fileName,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: generating ? null : onGenerate,
                  icon: generating
                      ? const SizedBox(
                          height: 14, width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.darkBg))
                      : const Icon(Icons.auto_awesome_outlined, size: 14),
                  label: Text(generating ? 'Generating...' : 'Ask Gemini',
                      style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2);
  }
}

class _QuestionsTab extends ConsumerWidget {
  final AsyncValue<List> questionsAsync;
  const _QuestionsTab({required this.questionsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questions = questionsAsync.asData?.value ?? [];
    if (questions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🤖', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text('No questions yet.\nUpload a slide and tap "Ask Gemini".',
                style: GoogleFonts.inter(color: AppColors.textMuted),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: questions.length,
      itemBuilder: (_, i) => QuestionCard(
        question: questions[i],
        showPushButton: true,
        onPush: () => SupabaseService.pushQuestion(questions[i].id),
      ),
    );
  }
}

class _ConfusedTab extends StatelessWidget {
  final List<ReactionModel> reactions;
  final int redCount;
  final bool generating;
  final VoidCallback onGenerate;

  const _ConfusedTab({
    required this.reactions, required this.redCount,
    required this.generating, required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final confused = reactions.where((r) => r.isRed).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: redCount > 0 ? AppColors.redBg : AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: redCount > 0 ? AppColors.red.withOpacity(0.4) : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Text('🔴', style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$redCount ${redCount == 1 ? 'student is' : 'students are'} confused',
                        style: GoogleFonts.inter(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: redCount > 0 ? AppColors.red : AppColors.textMuted,
                        ),
                      ),
                      Text(
                        redCount > 0
                            ? 'Gemini can generate targeted questions'
                            : 'No confusion signals yet',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: generating ? null : onGenerate,
              icon: generating
                  ? const SizedBox(
                      height: 16, width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.darkBg))
                  : const Icon(Icons.auto_awesome_outlined, size: 16),
              label: Text(generating
                  ? 'Generating clarifying questions...'
                  : 'Generate Clarifying Questions'),
            ),
          ).animate().fadeIn(delay: 100.ms),
          if (confused.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Confused Students',
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            ...confused.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.redBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Text('🔴', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Text(r.studentName,
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ).animate().fadeIn().slideX(begin: -0.1)),
          ],
        ],
      ),
    );
  }
}
