import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/gemini_service.dart';
import '../../services/supabase_service.dart';

class PolishScreen extends ConsumerStatefulWidget {
  const PolishScreen({super.key});

  @override
  ConsumerState<PolishScreen> createState() => _PolishScreenState();
}

class _PolishScreenState extends ConsumerState<PolishScreen> {
  final _inputCtrl = TextEditingController();
  String _mode = AppConstants.polishSoften;
  String? _output;
  bool _loading = false;
  String? _error;
  final _gemini = GeminiService();

  final _modes = [
    (id: 'soften', label: 'Soften Feedback', icon: '💬'),
    (id: 'strengthen', label: 'Strengthen Essay', icon: '💪'),
    (id: 'academic', label: 'Academic Polish', icon: '🎓'),
    (id: 'simplify', label: 'Simplify', icon: '✂️'),
  ];

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _polish() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Paste some text to polish first.');
      return;
    }
    if (text.length < 20) {
      setState(() => _error = 'Text is too short — add more context for better results.');
      return;
    }
    setState(() { _loading = true; _error = null; _output = null; });
    try {
      final result = await _gemini.polishText(text: text, mode: _mode);
      setState(() => _output = result);
      // Save to Supabase (best-effort)
      final user = ref.read(authStateProvider).asData?.value;
      if (user != null) {
        SupabaseService.savePolishLog(
          userId: user.id,
          inputText: text,
          outputText: result,
          mode: _mode,
        ).ignore();
      }
      // Save last 3 to local prefs for history
      _saveToHistory(text, result, _mode);
    } catch (e) {
      setState(() => _error = 'Gemini error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveToHistory(String input, String output, String mode) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'polish_history';
    final existing = prefs.getStringList(key) ?? [];
    final entry = '$mode|||${input.substring(0, input.length.clamp(0, 60))}|||$output';
    existing.insert(0, entry);
    if (existing.length > 5) existing.removeLast();
    await prefs.setStringList(key, existing);
  }

  void _copyOutput() {
    if (_output == null) return;
    Clipboard.setData(ClipboardData(text: _output!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Copied to clipboard!')),
    );
  }

  void _swapInputOutput() {
    if (_output == null) return;
    setState(() {
      _inputCtrl.text = _output!;
      _output = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Text Polish'),
        actions: [
          if (_output != null) ...[
            IconButton(
              icon: const Icon(Icons.swap_vert_outlined),
              tooltip: 'Use output as input',
              onPressed: _swapInputOutput,
            ),
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: 'Copy result',
              onPressed: _copyOutput,
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode selector
            Text('Choose mode',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500))
                .animate().fadeIn(),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _modes.map((m) {
                  final selected = _mode == m.id;
                  return GestureDetector(
                    onTap: () => setState(() { _mode = m.id; _output = null; }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.lime.withOpacity(0.1) : AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? AppColors.lime : AppColors.border,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(m.icon, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            m.label,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                              color: selected ? AppColors.lime : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ).animate().fadeIn(delay: 50.ms),
            const SizedBox(height: 20),

            // Mode description
            _ModeDescCard(mode: _mode).animate().fadeIn(delay: 80.ms),
            const SizedBox(height: 20),

            // Input
            Text('Your text',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500))
                .animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 8),
            TextField(
              controller: _inputCtrl,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: _modeHint(_mode),
                alignLabelWithHint: true,
              ),
              style: GoogleFonts.inter(fontSize: 14, height: 1.6),
            ).animate().fadeIn(delay: 120.ms),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.redBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.red.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: GoogleFonts.inter(color: AppColors.red, fontSize: 13)),
                    ),
                  ],
                ),
              ).animate().shakeX(),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _polish,
                icon: _loading
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.darkBg))
                    : const Icon(Icons.auto_awesome_outlined, size: 18),
                label: Text(_loading ? 'Polishing with Gemini...' : 'Polish with Gemini ✨'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ).animate().fadeIn(delay: 150.ms),

            // Output
            if (_output != null) ...[
              const SizedBox(height: 28),
              _OutputSection(
                original: _inputCtrl.text,
                polished: _output!,
                onCopy: _copyOutput,
                onUseAsInput: _swapInputOutput,
              ).animate().fadeIn().slideY(begin: 0.3),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _modeHint(String mode) {
    switch (mode) {
      case 'soften':
        return 'Paste harsh feedback here...\ne.g. "Your work is sloppy and shows no effort."';
      case 'strengthen':
        return 'Paste your essay or argument here...\ne.g. "Social media has positive effects on people."';
      case 'academic':
        return 'Paste your text to academify...\ne.g. "Kids learn better when teachers are fun."';
      case 'simplify':
        return 'Paste complex text to simplify...\ne.g. "The utilization of pedagogical methodologies..."';
      default:
        return 'Paste your text here...';
    }
  }
}

class _ModeDescCard extends StatelessWidget {
  final String mode;
  const _ModeDescCard({required this.mode});

  @override
  Widget build(BuildContext context) {
    final descs = {
      'soften': ('💬 Soften Feedback', 'Rewrites harsh criticism as constructive, encouraging feedback while keeping the core message.'),
      'strengthen': ('💪 Strengthen Essay', 'Improves argument structure, adds impact, and sharpens logical flow.'),
      'academic': ('🎓 Academic Polish', 'Elevates tone to formal academic writing with proper scholarly language.'),
      'simplify': ('✂️ Simplify', 'Breaks down complex language into clear, everyday English.'),
    };
    final desc = descs[mode]!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.purple.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.purple.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(desc.$1,
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: AppColors.purpleLight)),
                const SizedBox(height: 3),
                Text(desc.$2,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textMuted, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OutputSection extends StatelessWidget {
  final String original;
  final String polished;
  final VoidCallback onCopy;
  final VoidCallback onUseAsInput;

  const _OutputSection({
    required this.original, required this.polished,
    required this.onCopy, required this.onUseAsInput,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('✨', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text('Polished Result',
                style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Spacer(),
            TextButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_outlined, size: 14),
              label: const Text('Copy'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.lime.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.lime.withOpacity(0.25)),
          ),
          child: SelectableText(
            polished,
            style: GoogleFonts.inter(
                fontSize: 14, color: AppColors.textPrimary, height: 1.7),
          ),
        ),
        const SizedBox(height: 16),
        // Diff / comparison
        Text('What changed',
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(height: 8),
        _DiffView(original: original, polished: polished),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onUseAsInput,
            icon: const Icon(Icons.swap_vert_outlined, size: 16),
            label: const Text('Use result as new input'),
          ),
        ),
      ],
    );
  }
}

class _DiffView extends StatelessWidget {
  final String original;
  final String polished;

  const _DiffView({required this.original, required this.polished});

  List<TextSpan> _buildSpans() {
    final origWords = original.split(RegExp(r'\s+'));
    final newWords = polished.split(RegExp(r'\s+'));
    final origSet = origWords.toSet();
    final newSet = newWords.toSet();

    final spans = <TextSpan>[];
    for (final word in newWords) {
      if (!origSet.contains(word)) {
        spans.add(TextSpan(
          text: '$word ',
          style: const TextStyle(
            backgroundColor: Color(0x33CCFF00),
            color: AppColors.lime,
            fontWeight: FontWeight.w600,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: '$word ',
          style: const TextStyle(color: AppColors.textSecondary),
        ));
      }
    }
    for (final word in origWords) {
      if (!newSet.contains(word)) {
        spans.add(TextSpan(
          text: ' $word',
          style: const TextStyle(
            decoration: TextDecoration.lineThrough,
            color: AppColors.red,
          ),
        ));
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
              _Legend(color: AppColors.lime, label: 'Added / changed'),
              const SizedBox(width: 16),
              _Legend(color: AppColors.red, label: 'Removed', strikethrough: true),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: GoogleFonts.inter(fontSize: 13, height: 1.6),
              children: _buildSpans(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final bool strikethrough;

  const _Legend({required this.color, required this.label, this.strikethrough = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, color: color.withOpacity(0.6)),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10, color: AppColors.textMuted,
                decoration: strikethrough ? TextDecoration.lineThrough : null)),
      ],
    );
  }
}
