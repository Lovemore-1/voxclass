import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/supabase_service.dart';

class JoinSessionScreen extends ConsumerStatefulWidget {
  const JoinSessionScreen({super.key});

  @override
  ConsumerState<JoinSessionScreen> createState() => _JoinSessionScreenState();
}

class _JoinSessionScreenState extends ConsumerState<JoinSessionScreen> {
  final _focusNode = FocusNode();
  final _hiddenCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String _code = '';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _hiddenCtrl.dispose();
    _nameCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_code.length != 6) {
      setState(() => _error = 'Enter all 6 characters of the session code');
      return;
    }
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter your name to join');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await SupabaseService.getSessionByCode(_code);
      if (session == null) {
        setState(() => _error = 'Session not found or has already ended');
        return;
      }
      if (mounted) {
        context.go(
            '/class/student/${session.id}?name=${Uri.encodeComponent(_nameCtrl.text.trim())}');
      }
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top nav ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go('/dashboard'),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textMuted, size: 18),
                    ),
                    Text(
                      'Join Session',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ── Icon ─────────────────────────────────────────
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.indigo.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.indigo.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.login_outlined,
                              color: AppColors.indigo, size: 32),
                        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

                        const SizedBox(height: 20),

                        Text(
                          'Enter Session Code',
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.8,
                          ),
                        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),

                        const SizedBox(height: 6),

                        Text(
                          'Ask your lecturer for the 6-character code',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 14, color: AppColors.textMuted),
                        ).animate().fadeIn(delay: 150.ms),

                        const SizedBox(height: 40),

                        // ── OTP boxes ─────────────────────────────────────
                        GestureDetector(
                          onTap: () => _focusNode.requestFocus(),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  6,
                                  (i) => _OtpBox(
                                    char: i < _code.length ? _code[i] : '',
                                    active: i == _code.length,
                                    filled: i < _code.length,
                                  ),
                                ),
                              ),
                              Opacity(
                                opacity: 0,
                                child: TextField(
                                  controller: _hiddenCtrl,
                                  focusNode: _focusNode,
                                  autofocus: true,
                                  maxLength: 6,
                                  keyboardType: TextInputType.text,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[a-zA-Z0-9]')),
                                    LengthLimitingTextInputFormatter(6),
                                  ],
                                  onChanged: (v) => setState(() {
                                    _code = v.toUpperCase();
                                    _error = null;
                                  }),
                                  onSubmitted: (_) => _join(),
                                  decoration: const InputDecoration(counterText: ''),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 180.ms),

                        const SizedBox(height: 32),

                        // ── Name field ────────────────────────────────────
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Name',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _nameCtrl,
                              textCapitalization: TextCapitalization.words,
                              style: GoogleFonts.inter(
                                  color: AppColors.textPrimary, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'e.g. John Doe',
                                prefixIcon: const Icon(Icons.person_outline,
                                    color: AppColors.textMuted, size: 20),
                                filled: true,
                                fillColor: AppColors.cardGlass,
                              ),
                              onSubmitted: (_) => _join(),
                            ),
                          ],
                        ).animate().fadeIn(delay: 220.ms),

                        // ── Error message ─────────────────────────────────
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.redBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.red.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: AppColors.red, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: GoogleFonts.inter(
                                        color: AppColors.red, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn().shakeX(),
                        ],

                        const SizedBox(height: 28),

                        // ── Join button ───────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: _code.length == 6 &&
                                      _nameCtrl.text.trim().isNotEmpty
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFF6366F1),
                                        Color(0xFF4F46E5)
                                      ],
                                    )
                                  : null,
                              color: _code.length == 6 &&
                                      _nameCtrl.text.trim().isNotEmpty
                                  ? null
                                  : AppColors.card,
                              borderRadius: BorderRadius.circular(50),
                              boxShadow: _code.length == 6
                                  ? [
                                      BoxShadow(
                                        color: AppColors.indigo
                                            .withValues(alpha: 0.4),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      )
                                    ]
                                  : null,
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _loading ? null : _join,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50)),
                              ),
                              icon: _loading
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.login_outlined, size: 20),
                              label: Text(
                                _loading ? 'Joining...' : 'Join Session',
                                style: GoogleFonts.inter(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ).animate().fadeIn(delay: 260.ms),

                        const SizedBox(height: 32),

                        // ── How it works ──────────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'How it works',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _HowStep(
                                      icon: '1️⃣',
                                      label: 'Get code\nfrom lecturer'),
                                  Container(
                                      width: 1,
                                      height: 32,
                                      color: AppColors.border),
                                  _HowStep(
                                      icon: '2️⃣', label: 'Type it\nhere'),
                                  Container(
                                      width: 1,
                                      height: 32,
                                      color: AppColors.border),
                                  _HowStep(
                                      icon: '3️⃣',
                                      label: 'React &\nengage'),
                                ],
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 340.ms),
                      ],
                    ),
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

class _HowStep extends StatelessWidget {
  final String icon;
  final String label;
  const _HowStep({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              fontSize: 10, color: AppColors.textMuted, height: 1.4),
        ),
      ],
    );
  }
}

class _OtpBox extends StatelessWidget {
  final String char;
  final bool active;
  final bool filled;
  const _OtpBox(
      {required this.char, required this.active, required this.filled});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 46,
      height: 58,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: filled
            ? AppColors.indigo.withValues(alpha: 0.1)
            : AppColors.cardGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active
              ? AppColors.indigo
              : filled
                  ? AppColors.indigo.withValues(alpha: 0.5)
                  : AppColors.border,
          width: active ? 2 : 1.5,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                    color: AppColors.indigo.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 0)
              ]
            : null,
      ),
      child: Center(
        child: Text(
          char,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
