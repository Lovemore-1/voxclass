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
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    final name = _nameCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-character session code');
      return;
    }
    if (name.isEmpty) {
      setState(() => _error = 'Enter your name to join');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final session = await SupabaseService.getSessionByCode(code);
      if (session == null) {
        setState(() => _error = 'Session not found or has ended. Check the code and try again.');
        return;
      }
      if (mounted) context.go('/class/student/${session.id}?name=${Uri.encodeComponent(name)}');
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        title: const Text('Join a Class'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.lime.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.lime.withOpacity(0.3)),
                  ),
                  child: const Center(
                    child: Text('🎓', style: TextStyle(fontSize: 36)),
                  ),
                ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
              ),
              const SizedBox(height: 24),
              Text(
                'Join a live session',
                style: GoogleFonts.inter(
                  fontSize: 26, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary, letterSpacing: -0.8,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),
              const SizedBox(height: 6),
              Text(
                'Enter the 6-digit code from your lecturer',
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 130.ms),
              const SizedBox(height: 36),
              Text('Your Name',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500))
                  .animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g. Ahmad',
                  prefixIcon: Icon(Icons.person_outline, color: AppColors.textMuted),
                ),
              ).animate().fadeIn(delay: 170.ms).slideY(begin: 0.2),
              const SizedBox(height: 16),
              Text('Session Code',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500))
                  .animate().fadeIn(delay: 190.ms),
              const SizedBox(height: 8),
              TextField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]'))],
                style: GoogleFonts.inter(
                  fontSize: 28, fontWeight: FontWeight.w800,
                  color: AppColors.lime, letterSpacing: 8,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'ABC123',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 28, fontWeight: FontWeight.w800,
                    color: AppColors.textMuted, letterSpacing: 8,
                  ),
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ).animate().fadeIn(delay: 210.ms).slideY(begin: 0.2),
              if (_error != null) ...[
                const SizedBox(height: 12),
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
                ).animate().fadeIn().shakeX(),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _join,
                  child: _loading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.darkBg))
                      : const Text('Join Session'),
                ),
              ).animate().fadeIn(delay: 250.ms),
            ],
          ),
        ),
      ),
    );
  }
}
