import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../services/supabase_service.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _role = AppConstants.roleStudent;
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  bool _emailSent = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _emailSent = false;
    });
    try {
      final response = await SupabaseService.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        fullName: _nameCtrl.text.trim(),
        role: _role,
      );
      if (!mounted) return;
      if (response.session != null && response.user != null) {
        // Make sure the matching profiles row exists before we land on
        // the dashboard. Safe to call even if a DB trigger already created it.
        try {
          await SupabaseService.ensureProfile(
            userId: response.user!.id,
            fullName: _nameCtrl.text.trim(),
            role: _role,
          );
        } catch (_) {
          // Non-fatal — profileProvider will retry from user metadata.
        }
        if (!mounted) return;
        context.go('/dashboard');
      } else {
        setState(() => _emailSent = true);
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('User already registered') ||
          msg.contains('already registered')) {
        setState(() => _error =
            'An account with this email already exists. Try signing in.');
      } else {
        setState(() => _error = msg
            .replaceFirst('AuthException: ', '')
            .replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top nav ───────────────────────────────────────────────
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: AppColors.textMuted, size: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Create Account',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ).animate().fadeIn(),

                const SizedBox(height: 36),

                if (_emailSent) ...[
                  _EmailSentView(email: _emailCtrl.text.trim()),
                ] else ...[
                  // ── Headline ────────────────────────────────────────────
                  Text(
                    'Join VoxClass',
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -1,
                    ),
                  ).animate().fadeIn(delay: 60.ms).slideY(begin: 0.2),

                  const SizedBox(height: 6),

                  Text(
                    'Create your free account in seconds',
                    style: GoogleFonts.inter(
                        fontSize: 15, color: AppColors.textMuted),
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 32),

                  // ── Role selector ───────────────────────────────────────
                  Text(
                    'I am a...',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ).animate().fadeIn(delay: 120.ms),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _RoleCard(
                          emoji: '📖',
                          label: 'Student',
                          description: 'Join sessions & react',
                          selected: _role == AppConstants.roleStudent,
                          onTap: () =>
                              setState(() => _role = AppConstants.roleStudent),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RoleCard(
                          emoji: '🏫',
                          label: 'Lecturer',
                          description: 'Host & manage classes',
                          selected: _role == AppConstants.roleLecturer,
                          onTap: () =>
                              setState(() => _role = AppConstants.roleLecturer),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 140.ms),

                  const SizedBox(height: 28),

                  // ── Form ─────────────────────────────────────────────────
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Full Name',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            hintText: 'John Doe',
                            prefixIcon: Icon(Icons.person_outline,
                                color: AppColors.textMuted),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty
                                  ? 'Enter your name'
                                  : null,
                        ).animate().fadeIn(delay: 160.ms).slideY(begin: 0.15),

                        const SizedBox(height: 18),

                        Text(
                          'Email',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'you@example.com',
                            prefixIcon: Icon(Icons.mail_outline,
                                color: AppColors.textMuted),
                          ),
                          validator: (v) =>
                              v == null || !v.contains('@')
                                  ? 'Enter a valid email'
                                  : null,
                        ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.15),

                        const SizedBox(height: 18),

                        Text(
                          'Password',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            hintText: 'Min 6 characters',
                            prefixIcon: const Icon(Icons.lock_outline,
                                color: AppColors.textMuted),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.textMuted,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) =>
                              v == null || v.length < 6
                                  ? 'Min 6 characters'
                                  : null,
                          onFieldSubmitted: (_) => _signUp(),
                        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.15),

                        // ── Error ──────────────────────────────────────────
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.redBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.red.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: AppColors.red, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: GoogleFonts.inter(
                                        color: AppColors.red,
                                        fontSize: 13,
                                        height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn().shakeX(),
                        ],

                        const SizedBox(height: 28),

                        // ── Sign Up button ─────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                              ),
                              borderRadius: BorderRadius.circular(50),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.indigo.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _loading ? null : _signUp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50)),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(
                                      'Create Account',
                                      style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600),
                                    ),
                            ),
                          ),
                        ).animate().fadeIn(delay: 230.ms),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Sign In link ──────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(child: Divider(color: AppColors.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Have an account?',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                      ),
                      const Expanded(child: Divider(color: AppColors.border)),
                    ],
                  ).animate().fadeIn(delay: 260.ms),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => context.go('/login'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50)),
                      ),
                      child: Text(
                        'Sign In Instead',
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ).animate().fadeIn(delay: 280.ms),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Email Sent View ──────────────────────────────────────────────────────────

class _EmailSentView extends StatelessWidget {
  final String email;
  const _EmailSentView({required this.email});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.indigo.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
                color: AppColors.indigo.withValues(alpha: 0.3), width: 2),
          ),
          child: const Center(
              child: Text('📧', style: TextStyle(fontSize: 36))),
        ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
        const SizedBox(height: 24),
        Text(
          'Check your email!',
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ).animate().fadeIn(delay: 150.ms),
        const SizedBox(height: 10),
        Text(
          'We sent a confirmation link to\n$email',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textMuted,
            height: 1.6,
          ),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 8),
        Text(
          'Click the link, then come back and sign in.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
        ).animate().fadeIn(delay: 240.ms),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: AppColors.indigo.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () => context.go('/login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50)),
              ),
              child: Text(
                'Go to Sign In',
                style:
                    GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ).animate().fadeIn(delay: 300.ms),
      ],
    );
  }
}

// ─── Role Card ────────────────────────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.emoji,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.indigo.withValues(alpha: 0.08)
              : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.indigo
                : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.indigoLight : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.textMuted,
                  height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}
