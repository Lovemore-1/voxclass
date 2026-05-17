import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/anon_question_model.dart';
import '../../../models/reaction_model.dart';
import '../../../models/slide_model.dart';
import '../../../providers/session_provider.dart';
import '../../../services/gemini_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/supabase_service.dart';
import '../widgets/comprehension_timeline_chart.dart';
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
  bool _generatingReexplain = false;
  bool _clusteringAnon = false;
  List<Map<String, dynamic>> _anonClusters = [];

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
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'ppt', 'pptx'],
      withData: true,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _uploadingSlide = true);
    try {
      final slides = ref.read(slidesStreamProvider(widget.sessionId)).asData?.value ?? [];
      int uploadedCount = 0;
      for (int i = 0; i < result.files.length; i++) {
        final file = result.files[i];
        if (file.bytes == null) continue;
        final url = await StorageService.uploadSlide(
          sessionId: widget.sessionId,
          bytes: file.bytes!,
          fileName: file.name,
        );
        await SupabaseService.addSlide(
          sessionId: widget.sessionId,
          fileUrl: url,
          fileName: file.name,
          orderIndex: slides.length + i,
        );
        uploadedCount++;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ $uploadedCount slide${uploadedCount == 1 ? '' : 's'} uploaded!',
            ),
          ),
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

  Future<void> _deleteSlide(SlideModel slide) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Remove Slide?',
            style: GoogleFonts.inter(color: AppColors.textPrimary)),
        content: Text(
          'Remove "${slide.fileName}"? This cannot be undone.',
          style: GoogleFonts.inter(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await StorageService.deleteSlide(slide.fileUrl);
      await SupabaseService.deleteSlide(slide.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ Slide removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error removing slide: $e')));
      }
    }
  }

  Future<void> _generateQuestionsFromSlide(SlideModel slide,
      {String? sessionTitle, String? subject}) async {
    setState(() => _generatingQuestions = true);
    try {
      List<String> questions;

      if (StorageService.isAiAnalysable(slide.fileName)) {
        // Image / PDF — send bytes to Gemini vision
        final bytes = await StorageService.downloadSlide(slide.fileUrl);
        if (bytes == null) throw Exception('Could not download slide');
        final mime = StorageService.mimeTypeFor(slide.fileName);
        questions =
            await _gemini.generateQuestionsFromImage(bytes, mimeType: mime);
      } else {
        // PPTX / other — text-only fallback using session topic + file name
        debugPrint(
            '[VoxClass][AI] ${slide.fileName} is not AI-analysable → text-only fallback');
        final rawName = slide.fileName
            .replaceAll(RegExp(r'\.(pptx?|pdf|png|jpe?g|webp)$',
                caseSensitive: false),
                '')
            .replaceAll('_', ' ')
            .replaceAll('-', ' ');
        questions = await _gemini.generateQuestionsForTopic(
          sessionTitle: sessionTitle ?? rawName,
          subject: subject,
          context: rawName,
        );
      }

      // Save AND immediately push so students see them
      for (final q in questions) {
        await SupabaseService.saveAndPushQuestion(
          sessionId: widget.sessionId,
          questionText: q,
          sourceType: 'slide',
          slideId: slide.id,
        );
      }
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
      List<ReactionModel> reactions, String sessionTitle, String? subject,
      {SlideModel? currentSlide}) async {
    final red = reactions.where((r) => r.isRed).length;
    if (red == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No confused students detected yet.')),
      );
      return;
    }
    setState(() => _generatingClarifying = true);
    try {
      // Download current slide bytes for AI context if available
      Uint8List? slideBytes;
      String? slideMimeType;
      if (currentSlide != null && StorageService.isAiAnalysable(currentSlide.fileName)) {
        debugPrint('[VoxClass][AI] Downloading current slide for clarifying questions: ${currentSlide.fileName}');
        slideBytes = await StorageService.downloadSlide(currentSlide.fileUrl);
        slideMimeType = StorageService.mimeTypeFor(currentSlide.fileName);
        debugPrint('[VoxClass][AI] Clarifying prompt → slide=${currentSlide.fileName} mimeType=$slideMimeType confusedCount=$red');
      } else {
        debugPrint('[VoxClass][AI] Clarifying prompt → no slide (text-only) confusedCount=$red topic=$sessionTitle');
      }
      final questions = await _gemini.generateClarifyingQuestions(
        sessionTitle: sessionTitle,
        subject: subject,
        confusedCount: red,
        totalStudents: reactions.length,
        slideBytes: slideBytes,
        slideMimeType: slideMimeType,
      );
      // Save AND push immediately so students see them right away
      for (final q in questions) {
        await SupabaseService.saveAndPushQuestion(
          sessionId: widget.sessionId,
          questionText: q,
          sourceType: 'confused',
          slideId: currentSlide?.id,
        );
      }
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

  Future<void> _generateReexplanations(String topic, String? subject,
      {SlideModel? currentSlide}) async {
    setState(() => _generatingReexplain = true);
    try {
      Uint8List? slideBytes;
      String? slideMimeType;
      if (currentSlide != null && StorageService.isAiAnalysable(currentSlide.fileName)) {
        debugPrint('[VoxClass][AI] Downloading slide for re-explanation: ${currentSlide.fileName}');
        slideBytes = await StorageService.downloadSlide(currentSlide.fileUrl);
        slideMimeType = StorageService.mimeTypeFor(currentSlide.fileName);
        debugPrint('[VoxClass][AI] Re-explain prompt → slide=${currentSlide.fileName} topic=$topic');
      } else {
        debugPrint('[VoxClass][AI] Re-explain prompt → no slide (text-only) topic=$topic');
      }
      final options = await _gemini.generateReexplanations(
          topic: topic, subject: subject,
          slideBytes: slideBytes, slideMimeType: slideMimeType);
      if (!mounted) return;
      setState(() => _generatingReexplain = false);
      await showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.card,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _ReexplainSheet(
          options: options,
          onPush: (text) async {
            await SupabaseService.saveAndPushQuestion(
              sessionId: widget.sessionId,
              questionText: text,
              sourceType: 'reexplain',
              slideId: currentSlide?.id,  // tie to current slide
            );
            if (mounted) {
              _tabs.animateTo(2);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Re-explanation pushed to students!')),
              );
            }
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _generatingReexplain = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _clusterAnonymousQuestions(
      List<AnonQuestionModel> anonQuestions) async {
    if (anonQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No anonymous questions yet.')),
      );
      return;
    }
    setState(() => _clusteringAnon = true);
    try {
      final texts = anonQuestions.map((q) => q.questionText).toList();
      final clusters = await _gemini.clusterAnonymousQuestions(texts);
      setState(() => _anonClusters = clusters);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _clusteringAnon = false);
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
    final liveSessionAsync = ref.watch(sessionStateStreamProvider(widget.sessionId));
    final reactionsAsync = ref.watch(reactionsStreamProvider(widget.sessionId));
    final slidesAsync = ref.watch(slidesStreamProvider(widget.sessionId));
    final questionsAsync = ref.watch(questionsStreamProvider(widget.sessionId));
    final anonQAsync = ref.watch(anonQuestionsStreamProvider(widget.sessionId));

    return sessionAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.lime)),
      ),
      error: (_, __) => const Scaffold(body: Center(child: Text('Session not found'))),
      data: (initialSession) {
        final session = liveSessionAsync.asData?.value ?? initialSession;
        if (session == null) return const Scaffold(body: Center(child: Text('Not found')));
        final allReactions = reactionsAsync.asData?.value ?? [];
        final allSlides = slidesAsync.asData?.value ?? [];
        // Show only reactions for the CURRENT slide; fall back to all if no slide active
        final reactions = session.currentSlideId != null
            ? allReactions.where((r) => r.slideId == session.currentSlideId).toList()
            : allReactions;
        // Find the current active slide (for AI context)
        SlideModel? currentSlide;
        if (session.currentSlideId != null) {
          for (final s in allSlides) {
            if (s.id == session.currentSlideId) { currentSlide = s; break; }
          }
        }
        debugPrint('[VoxClass][Lecturer] Build → currentSlideId=${session.currentSlideId} reactions=${reactions.length} slides=${allSlides.length}');
        final green = reactions.where((r) => r.isGreen).length;
        final yellow = reactions.where((r) => r.isYellow).length;
        final red = reactions.where((r) => r.isRed).length;
        final anonQuestions = anonQAsync.asData?.value ?? [];

        return Container(
          decoration: const BoxDecoration(gradient: AppColors.bgGradient),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/dashboard'),
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
                    Text(session.code,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textMuted, letterSpacing: 2)),
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
                Tab(text: 'Signals'),
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
                sessionStart: session.createdAt,
              ),
              // ── Tab 2: Slides ────────────────────────────────────────
              _SlidesTab(
                slidesAsync: slidesAsync,
                uploading: _uploadingSlide,
                generating: _generatingQuestions,
                onUpload: _uploadSlide,
                onGenerateQuestions: (slide) => _generateQuestionsFromSlide(
                    slide,
                    sessionTitle: session.title,
                    subject: session.subject),
                onDelete: _deleteSlide,
              ),
              // ── Tab 3: Questions ─────────────────────────────────────
              _QuestionsTab(questionsAsync: questionsAsync),
              // ── Tab 4: Signals (Confused + Re-explain + Anon Q) ──────
              _SignalsTab(
                reactions: reactions,
                redCount: red,
                generating: _generatingClarifying,
                onGenerate: () => _generateClarifyingQuestions(
                    reactions, session.title, session.subject,
                    currentSlide: currentSlide),
                generatingReexplain: _generatingReexplain,
                onReexplain: () =>
                    _generateReexplanations(session.title, session.subject,
                    currentSlide: currentSlide),
                anonQuestions: anonQuestions,
                clusteringAnon: _clusteringAnon,
                anonClusters: _anonClusters,
                onClusterAnon: () => _clusterAnonymousQuestions(anonQuestions),
              ),
            ],
          ),
        ),
        );
      },
    );
  }
}

// ─── Mood Tab ────────────────────────────────────────────────────────────────

class _MoodTab extends StatelessWidget {
  final int green, yellow, red;
  final List<ReactionModel> reactions;
  final String code;
  final String sessionTitle;
  final DateTime sessionStart;

  const _MoodTab({
    required this.green, required this.yellow, required this.red,
    required this.reactions, required this.code, required this.sessionTitle,
    required this.sessionStart,
  });

  String _elapsed() {
    final mins = DateTime.now().difference(sessionStart).inMinutes;
    if (mins < 60) return '${mins}m';
    return '${mins ~/ 60}h ${mins % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    final total = green + yellow + red;
    final uniqueStudents = reactions.map((r) => r.studentId ?? r.studentName).toSet().length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ── 3 Stat Cards ──
          Row(
            children: [
              _StatCard(label: 'Code', value: code, icon: Icons.tag_outlined),
              const SizedBox(width: 10),
              _StatCard(
                  label: 'Students',
                  value: '$uniqueStudents',
                  icon: Icons.people_outline),
              const SizedBox(width: 10),
              _StatCard(
                  label: 'Time',
                  value: _elapsed(),
                  icon: Icons.timer_outlined),
            ],
          ).animate().fadeIn(),
          const SizedBox(height: 20),

          // ── Donut ──
          SizedBox(
            height: 240,
            child: MoodDonutChart(green: green, yellow: yellow, red: red),
          ).animate().fadeIn(delay: 80.ms),
          const SizedBox(height: 12),
          MoodLegend(green: green, yellow: yellow, red: red),

          if (total > 0) ...[
            const SizedBox(height: 8),
            Text('$total reaction${total == 1 ? '' : 's'} received',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          ],

          const SizedBox(height: 24),
          ComprehensionTimelineChart(
            reactions: reactions,
            sessionStart: sessionStart,
          ).animate().fadeIn(delay: 140.ms),
          const SizedBox(height: 24),
          QrDisplayWidget(code: code, sessionTitle: sessionTitle),
          const SizedBox(height: 24),
          if (reactions.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Recent Reactions',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppColors.textMuted)),
            ),
            const SizedBox(height: 8),
            ...reactions.take(8).map((r) => _ReactionRow(reaction: r)),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.indigo),
            const SizedBox(height: 6),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary, letterSpacing: 1),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10, color: AppColors.textMuted,
                    fontWeight: FontWeight.w500)),
          ],
        ),
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

// ─── Slides Tab ──────────────────────────────────────────────────────────────

class _SlidesTab extends StatelessWidget {
  final AsyncValue<List<SlideModel>> slidesAsync;
  final bool uploading;
  final bool generating;
  final VoidCallback onUpload;
  final void Function(SlideModel) onGenerateQuestions;
  final void Function(SlideModel) onDelete;

  const _SlidesTab({
    required this.slidesAsync, required this.uploading,
    required this.generating, required this.onUpload,
    required this.onGenerateQuestions, required this.onDelete,
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
              label: Text(uploading ? 'Uploading...' : 'Upload Slides (JPG / PNG / PDF / PPTX)'),
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
                  onDelete: () => onDelete(slide),
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
  final VoidCallback onDelete;

  const _SlideCard({
    required this.slide,
    required this.generating,
    required this.onGenerate,
    required this.onDelete,
  });

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
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(13)),
                child: _SlideThumbnail(slide: slide),
              ),
              // ── Delete button ─────────────────────────────────────────
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onDelete,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.delete_outline_rounded,
                          size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slide.fileName,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textMuted),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => context.push(
                            '/class/present/${slide.sessionId}/${slide.id}'),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Present',
                            style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          backgroundColor: AppColors.indigo,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: generating ? null : onGenerate,
                        icon: generating
                            ? const SizedBox(
                                height: 14,
                                width: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.textSecondary))
                            : const Icon(Icons.auto_awesome_outlined, size: 14),
                        label: Text(generating ? 'Generating…' : 'Ask Gemini',
                            style: const TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          side: const BorderSide(color: AppColors.border),
                          foregroundColor: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2);
  }
}

class _SlideThumbnail extends StatelessWidget {
  final SlideModel slide;
  const _SlideThumbnail({required this.slide});

  @override
  Widget build(BuildContext context) {
    final ext = slide.fileName.split('.').last.toLowerCase();
    final isImage = const {'png', 'jpg', 'jpeg', 'webp'}.contains(ext);

    if (isImage) {
      return Image.network(
        slide.fileUrl,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fileBadge(ext),
      );
    }
    return _fileBadge(ext);
  }

  Widget _fileBadge(String ext) {
    IconData icon;
    Color tint;
    String label;
    switch (ext) {
      case 'pdf':
        icon = Icons.picture_as_pdf_outlined;
        tint = const Color(0xFFEF4444);
        label = 'PDF';
        break;
      case 'ppt':
      case 'pptx':
        icon = Icons.slideshow_outlined;
        tint = const Color(0xFFF59E0B);
        label = 'PowerPoint';
        break;
      default:
        icon = Icons.insert_drive_file_outlined;
        tint = AppColors.textMuted;
        label = ext.toUpperCase();
    }
    return Container(
      height: 180,
      width: double.infinity,
      color: AppColors.border,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 44, color: tint),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Questions Tab ───────────────────────────────────────────────────────────

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
            Text('No questions yet.\nUpload a slide or use the Signals tab.',
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

// ─── Signals Tab (Confused + Re-explain + Anonymous Questions) ───────────────

class _SignalsTab extends StatelessWidget {
  final List<ReactionModel> reactions;
  final int redCount;
  final bool generating;
  final VoidCallback onGenerate;
  final bool generatingReexplain;
  final VoidCallback onReexplain;
  final List<AnonQuestionModel> anonQuestions;
  final bool clusteringAnon;
  final List<Map<String, dynamic>> anonClusters;
  final VoidCallback onClusterAnon;

  const _SignalsTab({
    required this.reactions, required this.redCount,
    required this.generating, required this.onGenerate,
    required this.generatingReexplain, required this.onReexplain,
    required this.anonQuestions, required this.clusteringAnon,
    required this.anonClusters, required this.onClusterAnon,
  });

  @override
  Widget build(BuildContext context) {
    final confused = reactions.where((r) => r.isRed).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Confusion counter ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: redCount > 0 ? AppColors.redBg : AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: redCount > 0 ? AppColors.red.withValues(alpha: 0.4) : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                const Text('🔴', style: TextStyle(fontSize: 28)),
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
                            ? 'Use the tools below to address confusion'
                            : 'No confusion signals yet',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(),
          const SizedBox(height: 12),

          // ── Generate clarifying questions ──
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: generating ? null : onGenerate,
              icon: generating
                  ? const SizedBox(
                      height: 16, width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_outlined, size: 16),
              label: Text(generating
                  ? 'Generating clarifying questions...'
                  : 'Generate Clarifying Questions'),
            ),
          ).animate().fadeIn(delay: 80.ms),
          const SizedBox(height: 10),

          // ── Re-explain button ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: generatingReexplain ? null : onReexplain,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple.withValues(alpha: 0.15),
                foregroundColor: AppColors.purpleLight,
                side: BorderSide(color: AppColors.purple.withValues(alpha: 0.4)),
              ),
              icon: generatingReexplain
                  ? const SizedBox(
                      height: 16, width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purpleLight))
                  : const Icon(Icons.replay_outlined, size: 16),
              label: Text(generatingReexplain
                  ? 'Generating re-explanations...'
                  : '⚡ Re-explain This Topic'),
            ),
          ).animate().fadeIn(delay: 120.ms),

          if (confused.isNotEmpty) ...[
            const SizedBox(height: 20),
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
                    border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Text('🔴', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Text(r.studentName,
                          style:
                              GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ).animate().fadeIn().slideX(begin: -0.1)),
          ],

          // ── Anonymous Questions ──
          const SizedBox(height: 28),
          Row(
            children: [
              Text('Anonymous Questions',
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.lime.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${anonQuestions.length}',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.lime, fontWeight: FontWeight.w700)),
              ),
            ],
          ).animate().fadeIn(delay: 160.ms),
          const SizedBox(height: 4),
          Text('Students can ask questions anonymously',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))
              .animate().fadeIn(delay: 180.ms),
          const SizedBox(height: 12),

          if (anonQuestions.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Text('No questions submitted yet',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
              ),
            ).animate().fadeIn(delay: 200.ms)
          else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: clusteringAnon ? null : onClusterAnon,
                icon: clusteringAnon
                    ? const SizedBox(
                        height: 16, width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.darkBg))
                    : const Icon(Icons.hub_outlined, size: 16),
                label: Text(clusteringAnon
                    ? 'Clustering questions...'
                    : '🧠 Cluster with Gemini'),
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 12),
            if (anonClusters.isNotEmpty) ...[
              ...anonClusters.map((c) => _ClusterCard(cluster: c)
                  .animate().fadeIn().slideY(begin: 0.2)),
            ] else ...[
              ...anonQuestions.take(10).map((q) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Text('💬', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(q.questionText,
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: AppColors.textSecondary, height: 1.3)),
                        ),
                      ],
                    ),
                  ).animate().fadeIn()),
            ],
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ClusterCard extends StatelessWidget {
  final Map<String, dynamic> cluster;
  const _ClusterCard({required this.cluster});

  @override
  Widget build(BuildContext context) {
    final theme = cluster['theme'] as String? ?? 'General';
    final count = cluster['count'] as int? ?? 1;
    final sample = cluster['sample'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lime.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lime.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(theme,
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.lime.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$count students',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: AppColors.lime, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (sample.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('"$sample"',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textMuted,
                    fontStyle: FontStyle.italic, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

// ─── Re-explain Bottom Sheet ─────────────────────────────────────────────────

class _ReexplainSheet extends StatefulWidget {
  final List<Map<String, String>> options;
  final Future<void> Function(String text) onPush;
  const _ReexplainSheet({required this.options, required this.onPush});

  @override
  State<_ReexplainSheet> createState() => _ReexplainSheetState();
}

class _ReexplainSheetState extends State<_ReexplainSheet> {
  String? _pushing;

  static const _icons = {'analogy': '💡', 'steps': '📋', 'example': '🎯'};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20,
          MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text('⚡ Re-explain This Topic',
              style: GoogleFonts.inter(
                  fontSize: 17, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Pick the best explanation to push to all students',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 16),
          ...widget.options.map((opt) {
            final type = opt['type'] ?? '';
            final label = opt['label'] ?? '';
            final text = opt['text'] ?? '';
            final icon = _icons[type] ?? '💡';
            final isPushing = _pushing == type;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(label,
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: AppColors.purpleLight)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(text,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _pushing != null
                          ? null
                          : () async {
                              setState(() => _pushing = type);
                              await widget.onPush(text);
                            },
                      child: isPushing
                          ? const SizedBox(
                              height: 16, width: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.darkBg))
                          : const Text('Push to Class →'),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
