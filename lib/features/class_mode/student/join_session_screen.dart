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
      setState(() => _error = 'Enter all 6 digits of the session code');
      return;
    }
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter your name to join');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final session = await SupabaseService.getSessionByCode(_code);
      if (session == null) {
        setState(() => _error = 'Session not found or has ended');
        return;
      }
      if (mounted) {
        context.go('/class/student/${session.id}?name=${Uri.encodeComponent(_nameCtrl.text.trim())}');
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
              // Back button
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.go('/dashboard'),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: Text('Back', style: GoogleFonts.inter(fontSize: 14)),
                  style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Join Session',
                            style: GoogleFonts.inter(
                              fontSize: 28, fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            )).animate().fadeIn().slideY(begin: 0.2),
                        const SizedBox(height: 8),
                        Text('Enter the 6-digit session code',
                            style: GoogleFonts.inter(
                                fontSize: 14, color: AppColors.textMuted))
                            .animate().fadeIn(delay: 80.ms),
                        const SizedBox(height: 40),

                        // OTP boxes
                        GestureDetector(
                          onTap: () => _focusNode.requestFocus(),
                          child: Stack(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(6, (i) => _OtpBox(
                                  char: i < _code.length ? _code[i] : '',
                                  active: i == _code.length,
                                )),
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
                                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                                    LengthLimitingTextInputFormatter(6),
                                  ],
                                  onChanged: (v) => setState(() {
                                    _code = v.toUpperCase();
                                    _error = null;
                                  }),
                                  decoration: const InputDecoration(counterText: ''),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 120.ms),

                        const SizedBox(height: 32),

                        // Name field
                        TextField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Your name',
                            prefixIcon: const Icon(Icons.person_outline,
                                color: AppColors.textMuted, size: 20),
                            filled: true,
                            fillColor: AppColors.cardGlass,
                          ),
                          onSubmitted: (_) => _join(),
                        ).animate().fadeIn(delay: 160.ms),

                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.redBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.red, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_error!,
                                      style: GoogleFonts.inter(
                                          color: AppColors.red, fontSize: 13)),
                                ),
                              ],
                            ),
                          ).animate().fadeIn().shakeX(),
                        ],

                        const SizedBox(height: 28),

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: _loading ? null : _join,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.indigo,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50)),
                            ),
                            icon: _loading
                                ? const SizedBox(height: 18, width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.login_outlined, size: 18),
                            label: Text(_loading ? 'Joining...' : 'Join Session',
                                style: GoogleFonts.inter(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ).animate().fadeIn(delay: 200.ms),
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

class _OtpBox extends StatelessWidget {
  final String char;
  final bool active;
  const _OtpBox({required this.char, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 48, height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: AppColors.cardGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active
              ? AppColors.indigo
              : char.isNotEmpty
                  ? AppColors.borderLight
                  : AppColors.border,
          width: active ? 2 : 1,
        ),
        boxShadow: active
            ? [BoxShadow(
                color: AppColors.indigo.withValues(alpha: 0.3),
                blurRadius: 8)]
            : null,
      ),
      child: Center(
        child: Text(
          char,
          style: GoogleFonts.inter(
            fontSize: 22, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary, letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
