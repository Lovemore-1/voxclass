import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/question_model.dart';

class QuestionCard extends StatelessWidget {
  final QuestionModel question;
  final VoidCallback? onPush;
  final bool showPushButton;
  final bool canRespond;
  final void Function(String)? onRespond;

  const QuestionCard({
    super.key,
    required this.question,
    this.onPush,
    this.showPushButton = false,
    this.canRespond = false,
    this.onRespond,
  });

  Color get _sourceColor => question.isFromSlide ? AppColors.lime : AppColors.amber;
  String get _sourceLabel => question.isFromSlide ? '📊 From Slide' : '🔴 Confused Students';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: question.isPushed ? _sourceColor.withValues(alpha: 0.4) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _sourceColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _sourceLabel,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: _sourceColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (question.isPushed) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '✓ Pushed',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            question.questionText,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
          if (showPushButton && !question.isPushed) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onPush,
                icon: const Icon(Icons.send_outlined, size: 16),
                label: const Text('Push to Students'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lime,
                  foregroundColor: AppColors.darkBg,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
          if (canRespond) _ResponseInput(onRespond: onRespond),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2);
  }
}

class _ResponseInput extends StatefulWidget {
  final void Function(String)? onRespond;

  const _ResponseInput({this.onRespond});

  @override
  State<_ResponseInput> createState() => _ResponseInputState();
}

class _ResponseInputState extends State<_ResponseInput> {
  final _ctrl = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.green, size: 16),
            const SizedBox(width: 6),
            Text(
              'Response submitted!',
              style: GoogleFonts.inter(color: AppColors.green, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                hintText: 'Type your answer...',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: GoogleFonts.inter(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              if (_ctrl.text.trim().isNotEmpty) {
                widget.onRespond?.call(_ctrl.text.trim());
                setState(() => _submitted = true);
              }
            },
            icon: const Icon(Icons.send, color: AppColors.lime),
          ),
        ],
      ),
    );
  }
}
