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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await SupabaseService.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        fullName: _nameCtrl.text.trim(),
        role: _role,
      );
      if (mounted) context.go('/dashboard');
    } catch (e) {
      setState(() => _error = 'Sign up failed. Email may already be in use.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.arrow_back, color: AppColors.textMuted),
              ).animate().fadeIn(),
              const SizedBox(height: 16),
              Text(
                'Create account',
                style: GoogleFonts.inter(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -1,
                ),
              ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.3),
              const SizedBox(height: 8),
              Text(
                'Join VoxClass today',
                style: GoogleFonts.inter(fontSize: 16, color: AppColors.textMuted),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 32),
              // Role selector
              Text(
                'I am a...',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
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
                      selected: _role == AppConstants.roleStudent,
                      onTap: () => setState(() => _role = AppConstants.roleStudent),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RoleCard(
                      emoji: '🏫',
                      label: 'Lecturer',
                      selected: _role == AppConstants.roleLecturer,
                      onTap: () => setState(() => _role = AppConstants.roleLecturer),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 140.ms),
              const SizedBox(height: 28),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline, color: AppColors.textMuted),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Enter your name' : null,
                    ).animate().fadeIn(delay: 160.ms).slideY(begin: 0.2),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline, color: AppColors.textMuted),
                      ),
                      validator: (v) =>
                          v == null || !v.contains('@') ? 'Enter a valid email' : null,
                    ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.2),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.length < 6 ? 'Min 6 characters' : null,
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
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
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _signUp,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.darkBg,
                                ),
                              )
                            : const Text('Create Account'),
                      ),
                    ).animate().fadeIn(delay: 220.ms),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
                  ),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Sign In'),
                  ),
                ],
              ).animate().fadeIn(delay: 240.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: selected ? AppColors.lime.withOpacity(0.1) : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.lime : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.lime : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
