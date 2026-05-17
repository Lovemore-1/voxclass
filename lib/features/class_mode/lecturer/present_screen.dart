import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/reaction_model.dart';
import '../../../models/slide_model.dart';
import '../../../providers/session_provider.dart';
import '../../../services/supabase_service.dart';
import '../widgets/file_viewer.dart';

class PresentScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String startSlideId;
  const PresentScreen({
    super.key,
    required this.sessionId,
    required this.startSlideId,
  });

  @override
  ConsumerState<PresentScreen> createState() => _PresentScreenState();
}

class _PresentScreenState extends ConsumerState<PresentScreen> {
  late String _currentSlideId;
  int _currentPage = 1; // page within the current PDF
  Timer? _pointerThrottle;
  DateTime _lastPointerSend = DateTime.fromMillisecondsSinceEpoch(0);

  final _notesCtrl = TextEditingController();
  String? _notesSlideId;
  Timer? _notesDebounce;

  bool _statsVisible = true;
  bool _fullscreen = false;

  @override
  void initState() {
    super.initState();
    _currentSlideId = widget.startSlideId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[VoxClass][Lecturer] Broadcasting initial slide → $_currentSlideId');
      SupabaseService.setCurrentSlide(
        sessionId: widget.sessionId,
        slideId: _currentSlideId,
      );
      // Reset to page 1 when presentation starts
      SupabaseService.setCurrentPage(sessionId: widget.sessionId, page: 1);
    });
  }

  @override
  void dispose() {
    _pointerThrottle?.cancel();
    _notesDebounce?.cancel();
    _notesCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SupabaseService.setCurrentSlide(sessionId: widget.sessionId, slideId: null);
    SupabaseService.updatePointer(
      sessionId: widget.sessionId,
      x: null,
      y: null,
      visible: false,
    );
    super.dispose();
  }

  void _toggleFullscreen() {
    setState(() => _fullscreen = !_fullscreen);
    if (_fullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _go(List<SlideModel> slides, int direction) {
    if (slides.isEmpty) return;
    final idx = slides.indexWhere((s) => s.id == _currentSlideId);
    final nextIdx = (idx + direction).clamp(0, slides.length - 1);
    if (nextIdx == idx) return;
    final nextSlide = slides[nextIdx];
    debugPrint('[VoxClass][Lecturer] Slide change: ${nextIdx + 1}/${slides.length} → id=${nextSlide.id} name=${nextSlide.fileName}');
    setState(() {
      _currentSlideId = nextSlide.id;
      _currentPage = 1; // reset page when changing files
    });
    SupabaseService.setCurrentSlide(sessionId: widget.sessionId, slideId: nextSlide.id);
    SupabaseService.setCurrentPage(sessionId: widget.sessionId, page: 1);
  }

  void _goPage(int direction) {
    final newPage = (_currentPage + direction).clamp(1, 999);
    if (newPage == _currentPage) return;
    debugPrint('[VoxClass][Lecturer] Page change: $newPage');
    setState(() => _currentPage = newPage);
    SupabaseService.setCurrentPage(sessionId: widget.sessionId, page: newPage);
  }

  void _sendPointer(double nx, double ny, {required bool visible}) {
    final now = DateTime.now();
    if (now.difference(_lastPointerSend).inMilliseconds < 80 && visible) {
      _pointerThrottle?.cancel();
      _pointerThrottle = Timer(const Duration(milliseconds: 80), () {
        _lastPointerSend = DateTime.now();
        SupabaseService.updatePointer(
          sessionId: widget.sessionId,
          x: nx,
          y: ny,
          visible: visible,
        );
      });
      return;
    }
    _lastPointerSend = now;
    SupabaseService.updatePointer(
      sessionId: widget.sessionId,
      x: nx,
      y: ny,
      visible: visible,
    );
  }

  void _syncNotesToCurrent(SlideModel slide) {
    if (_notesSlideId != slide.id) {
      _notesSlideId = slide.id;
      _notesCtrl.text = slide.speakerNotes ?? '';
    }
  }

  void _onNotesChanged(String value) {
    _notesDebounce?.cancel();
    _notesDebounce = Timer(const Duration(milliseconds: 600), () {
      if (_notesSlideId == null) return;
      SupabaseService.updateSpeakerNotes(
        slideId: _notesSlideId!,
        notes: value,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final slidesAsync = ref.watch(slidesStreamProvider(widget.sessionId));
    final reactionsAsync = ref.watch(reactionsStreamProvider(widget.sessionId));
    final reactions = reactionsAsync.asData?.value ?? [];
    final green = reactions.where((r) => r.isGreen).length;
    final yellow = reactions.where((r) => r.isYellow).length;
    final red = reactions.where((r) => r.isRed).length;
    final total = green + yellow + red;
    final uniqueStudents =
        reactions.map((r) => r.studentId ?? r.studentName).toSet().length;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: slidesAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.indigo)),
          error: (e, _) => Center(
              child: Text('Error: $e',
                  style: const TextStyle(color: AppColors.textMuted))),
          data: (slides) {
            if (slides.isEmpty) {
              return const Center(
                child: Text('No slides to present',
                    style: TextStyle(color: AppColors.textMuted)),
              );
            }
            final idx = slides.indexWhere((s) => s.id == _currentSlideId);
            final currentIdx = idx < 0 ? 0 : idx;
            final slide = slides[currentIdx];
            _syncNotesToCurrent(slide);

            return LayoutBuilder(builder: (context, constraints) {
              final isWide = constraints.maxWidth > 820;
              final showSidePanel = isWide && _statsVisible && !_fullscreen;

              return Column(
                children: [
                  // ── Top bar (hidden in fullscreen) ─────────────────
                  if (!_fullscreen)
                    _TopBar(
                      currentIdx: currentIdx,
                      total: slides.length,
                      currentPage: _currentPage,
                      isPdf: slide.fileName.toLowerCase().endsWith('.pdf'),
                      statsVisible: _statsVisible,
                      isWide: isWide,
                      onToggleStats: () =>
                          setState(() => _statsVisible = !_statsVisible),
                      onToggleFullscreen: _toggleFullscreen,
                      onClose: () => context.pop(),
                    ),

                  // ── Confused alert banner ──────────────────────────
                  if (red > 0 && total > 0 && !_fullscreen)
                    _ConfusedBanner(redCount: red, total: total),

                  // ── Main content row ───────────────────────────────
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Slide column
                        Expanded(
                          child: Column(
                            children: [
                              // Slide stage
                              Expanded(
                                flex: 5,
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    12,
                                    _fullscreen ? 12 : 8,
                                    showSidePanel ? 6 : 12,
                                    8,
                                  ),
                                  child: Stack(
                                    children: [
                                      _SlideStage(
                                        slide: slide,
                                        currentPage: _currentPage,
                                        onPointer: _sendPointer,
                                      ),
                                      // Fullscreen: compact HUD overlay
                                      if (_fullscreen)
                                        Positioned(
                                          top: 12,
                                          right: 12,
                                          child: _FullscreenHud(
                                            green: green,
                                            yellow: yellow,
                                            red: red,
                                            uniqueStudents: uniqueStudents,
                                            onExit: _toggleFullscreen,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),

                              // Speaker notes (hidden in fullscreen)
                              if (!_fullscreen)
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 0, 12, 0),
                                    child: _SpeakerNotesPanel(
                                      controller: _notesCtrl,
                                      onChanged: _onNotesChanged,
                                    ),
                                  ),
                                ),

                              // Nav bar
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  12,
                                  8,
                                  showSidePanel ? 6 : 12,
                                  _fullscreen ? 8 : 16,
                                ),
                                child: _NavBar(
                                  currentIdx: currentIdx,
                                  total: slides.length,
                                  currentPage: _currentPage,
                                  isPdf: slide.fileName.toLowerCase().endsWith('.pdf'),
                                  fullscreen: _fullscreen,
                                  onPrev: () => _go(slides, -1),
                                  onNext: () => _go(slides, 1),
                                  onPrevPage: () => _goPage(-1),
                                  onNextPage: () => _goPage(1),
                                  onToggleFullscreen: _toggleFullscreen,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Side stats panel (wide + stats on + not fullscreen)
                        if (showSidePanel)
                          _LiveStatsPanel(
                            green: green,
                            yellow: yellow,
                            red: red,
                            uniqueStudents: uniqueStudents,
                            reactions: reactions,
                          ),
                      ],
                    ),
                  ),

                  // Narrow screen compact stats bar
                  if (!isWide && _statsVisible && !_fullscreen)
                    _CompactStatsBar(
                      green: green,
                      yellow: yellow,
                      red: red,
                      uniqueStudents: uniqueStudents,
                    ),
                ],
              );
            });
          },
        ),
      ),
    );
  }
}

// ─── Top Bar ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int currentIdx;
  final int total;
  final int currentPage;
  final bool isPdf;
  final bool statsVisible;
  final bool isWide;
  final VoidCallback onToggleStats;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onClose;

  const _TopBar({
    required this.currentIdx,
    required this.total,
    required this.statsVisible,
    required this.isWide,
    required this.onToggleStats,
    required this.onToggleFullscreen,
    required this.onClose,
    this.currentPage = 1,
    this.isPdf = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 4),
          // PRESENTING badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AppColors.red.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: AppColors.red, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text('PRESENTING',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.red)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isPdf
                ? (total > 1 ? 'File ${currentIdx + 1}/$total • Page $currentPage' : 'Page $currentPage')
                : 'Slide ${currentIdx + 1} / $total',
            style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          // Stats toggle
          IconButton(
            tooltip: statsVisible ? 'Hide live stats' : 'Show live stats',
            onPressed: onToggleStats,
            icon: Icon(
              statsVisible
                  ? Icons.analytics_outlined
                  : Icons.analytics,
              color: statsVisible
                  ? AppColors.lime
                  : AppColors.textSecondary,
              size: 20,
            ),
          ),
          // Fullscreen toggle
          IconButton(
            tooltip: 'Full presentation mode',
            onPressed: onToggleFullscreen,
            icon: const Icon(Icons.fullscreen_outlined,
                color: AppColors.textSecondary, size: 20),
          ),
          TextButton.icon(
            onPressed: onClose,
            icon: const Icon(Icons.stop_circle_outlined,
                size: 18, color: AppColors.red),
            label:
                const Text('End', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }
}

// ─── Confused Alert Banner ────────────────────────────────────────────────────

class _ConfusedBanner extends StatelessWidget {
  final int redCount;
  final int total;
  const _ConfusedBanner({required this.redCount, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (redCount / total * 100).round() : 0;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Text('🔴', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$redCount student${redCount == 1 ? '' : 's'} confused ($pct%) — consider pausing to clarify',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.red,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Slide Stage ─────────────────────────────────────────────────────────────

class _SlideStage extends StatelessWidget {
  final SlideModel slide;
  final int currentPage;
  final void Function(double nx, double ny, {required bool visible}) onPointer;
  const _SlideStage({required this.slide, required this.onPointer, this.currentPage = 1});

  @override
  Widget build(BuildContext context) {
    final ext = slide.fileName.split('.').last.toLowerCase();
    final isImage = const {'png', 'jpg', 'jpeg', 'webp'}.contains(ext);

    return LayoutBuilder(
      builder: (context, c) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: GestureDetector(
            onTapDown: (d) => onPointer(
              d.localPosition.dx / c.maxWidth,
              d.localPosition.dy / c.maxHeight,
              visible: true,
            ),
            onPanUpdate: (d) => onPointer(
              d.localPosition.dx / c.maxWidth,
              d.localPosition.dy / c.maxHeight,
              visible: true,
            ),
            onPanEnd: (_) => onPointer(0, 0, visible: false),
            onTapUp: (_) => onPointer(0, 0, visible: false),
            child: Container(
              width: c.maxWidth,
              height: c.maxHeight,
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: AppColors.border),
              ),
              child: isImage
                  ? Image.network(slide.fileUrl, fit: BoxFit.contain)
                  : SizedBox(
                      width: c.maxWidth,
                      height: c.maxHeight,
                      child: FileViewer(
                        fileUrl: slide.fileUrl,
                        fileName: slide.fileName,
                        currentPage: currentPage,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Speaker Notes Panel ─────────────────────────────────────────────────────

class _SpeakerNotesPanel extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SpeakerNotesPanel(
      {required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notes, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text('Speaker notes (only you see this)',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              onChanged: onChanged,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  height: 1.45),
              decoration: const InputDecoration(
                hintText: 'Type a private reminder for this slide…',
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Nav Bar ─────────────────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  final int currentIdx;
  final int total;
  final int currentPage;
  final bool isPdf;
  final bool fullscreen;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPrevPage;
  final VoidCallback onNextPage;
  final VoidCallback onToggleFullscreen;

  const _NavBar({
    required this.currentIdx,
    required this.total,
    required this.fullscreen,
    required this.onPrev,
    required this.onNext,
    required this.onToggleFullscreen,
    this.currentPage = 1,
    this.isPdf = false,
    required this.onPrevPage,
    required this.onNextPage,
  });

  @override
  Widget build(BuildContext context) {
    // For a single PDF file, show PAGE navigation instead of file navigation
    final singlePdf = isPdf && total <= 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── File navigation (shown when multiple files uploaded) ──
        if (total > 1)
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: currentIdx == 0 ? null : onPrev,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Prev File'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: AppColors.border),
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: IconButton(
                tooltip: fullscreen ? 'Exit fullscreen' : 'Fullscreen',
                onPressed: onToggleFullscreen,
                icon: Icon(fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: currentIdx >= total - 1 ? null : onNext,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Next File'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: AppColors.indigo,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ]),

        if (total > 1 && isPdf) const SizedBox(height: 8),

        // ── Page navigation for PDFs ──
        if (isPdf)
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: currentPage <= 1 ? null : onPrevPage,
                icon: const Icon(Icons.arrow_back_ios, size: 14),
                label: const Text('Prev Page'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: AppColors.border),
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (singlePdf)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: IconButton(
                  tooltip: fullscreen ? 'Exit fullscreen' : 'Fullscreen',
                  onPressed: onToggleFullscreen,
                  icon: Icon(fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                      color: AppColors.textSecondary),
                ),
              ),
            if (singlePdf) const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onNextPage,
                icon: const Icon(Icons.arrow_forward_ios, size: 14),
                label: const Text('Next Page'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: AppColors.indigo,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ]),

        // ── Fullscreen button alone when no PDF and single file ──
        if (!isPdf && total <= 1)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: IconButton(
                tooltip: fullscreen ? 'Exit fullscreen' : 'Fullscreen',
                onPressed: onToggleFullscreen,
                icon: Icon(fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: AppColors.textSecondary),
              ),
            ),
          ]),
      ],
    );
  }
}

// ─── Live Stats Side Panel ────────────────────────────────────────────────────

class _LiveStatsPanel extends StatelessWidget {
  final int green;
  final int yellow;
  final int red;
  final int uniqueStudents;
  final List<ReactionModel> reactions;

  const _LiveStatsPanel({
    required this.green,
    required this.yellow,
    required this.red,
    required this.uniqueStudents,
    required this.reactions,
  });

  @override
  Widget build(BuildContext context) {
    final total = green + yellow + red;
    final recent = reactions.take(8).toList();
    // ignore: unused_local_variable — kept for symmetry with other panels

    return Container(
      width: 220,
      margin: const EdgeInsets.fromLTRB(0, 0, 12, 0),
      child: Column(
        children: [
          // ── Mood counts ─────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PanelHeader(
                      icon: Icons.bar_chart_outlined, label: 'Live Class Mood'),
                  const SizedBox(height: 10),

                  // Mood bars
                  _MoodBar(
                    emoji: '🟢',
                    label: 'Got it',
                    count: green,
                    total: total,
                    color: AppColors.green,
                  ),
                  const SizedBox(height: 6),
                  _MoodBar(
                    emoji: '🟡',
                    label: 'Unsure',
                    count: yellow,
                    total: total,
                    color: AppColors.amber,
                  ),
                  const SizedBox(height: 6),
                  _MoodBar(
                    emoji: '🔴',
                    label: 'Confused',
                    count: red,
                    total: total,
                    color: AppColors.red,
                  ),
                  const SizedBox(height: 14),

                  // Student count
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.people_outline,
                            size: 16, color: AppColors.indigo),
                        const SizedBox(width: 8),
                        Text(
                          '$uniqueStudents student${uniqueStudents == 1 ? '' : 's'} active',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (total == 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          const Text('👂',
                              style: TextStyle(fontSize: 24)),
                          const SizedBox(height: 6),
                          Text(
                            'Waiting for students\nto react…',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textMuted,
                                height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ] else if (recent.isNotEmpty) ...[
                    _PanelHeader(
                        icon: Icons.bolt_outlined, label: 'Live Feed'),
                    const SizedBox(height: 8),
                    ...recent.map((r) => _ReactionFeedRow(reaction: r)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Fullscreen HUD overlay ───────────────────────────────────────────────────

class _FullscreenHud extends StatelessWidget {
  final int green;
  final int yellow;
  final int red;
  final int uniqueStudents;
  final VoidCallback onExit;

  const _FullscreenHud({
    required this.green,
    required this.yellow,
    required this.red,
    required this.uniqueStudents,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final total = green + yellow + red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.darkBg.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (total == 0) ...[
            Text('👂  Waiting…',
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.textMuted)),
            const SizedBox(width: 12),
          ] else ...[
            _HudChip('🟢', '$green'),
            const SizedBox(width: 10),
            _HudChip('🟡', '$yellow'),
            const SizedBox(width: 10),
            _HudChip('🔴', '$red'),
            const SizedBox(width: 14),
            const Icon(Icons.people_outline,
                size: 14, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text('$uniqueStudents',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(width: 12),
          ],
          GestureDetector(
            onTap: onExit,
            child: const Icon(Icons.fullscreen_exit,
                size: 18, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  final String emoji;
  final String count;
  const _HudChip(this.emoji, this.count);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 4),
        Text(count,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      ],
    );
  }
}

// ─── Compact Stats Bar (narrow screens) ──────────────────────────────────────

class _CompactStatsBar extends StatelessWidget {
  final int green;
  final int yellow;
  final int red;
  final int uniqueStudents;

  const _CompactStatsBar({
    required this.green,
    required this.yellow,
    required this.red,
    required this.uniqueStudents,
  });

  @override
  Widget build(BuildContext context) {
    final total = green + yellow + red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: total == 0
          ? Center(
              child: Text(
                '👂  Waiting for students to react…',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textMuted),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _CompactChip('🟢', '$green', 'Got it', AppColors.green),
                _CompactChip('🟡', '$yellow', 'Unsure', AppColors.amber),
                _CompactChip('🔴', '$red', 'Confused', AppColors.red),
                Row(
                  children: [
                    const Icon(Icons.people_outline,
                        size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text('$uniqueStudents',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ],
                ),
              ],
            ),
    );
  }
}

class _CompactChip extends StatelessWidget {
  final String emoji;
  final String count;
  final String label;
  final Color color;
  const _CompactChip(this.emoji, this.count, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(count,
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 9,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PanelHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
      ],
    );
  }
}

class _MoodBar extends StatelessWidget {
  final String emoji;
  final String label;
  final int count;
  final int total;
  final Color color;
  const _MoodBar({
    required this.emoji,
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.textSecondary)),
            const Spacer(),
            Text('$count',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.toDouble(),
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _ReactionFeedRow extends StatelessWidget {
  final ReactionModel reaction;
  const _ReactionFeedRow({required this.reaction});

  @override
  Widget build(BuildContext context) {
    final emoji =
        reaction.isGreen ? '🟢' : reaction.isYellow ? '🟡' : '🔴';
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reaction.studentName,
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
