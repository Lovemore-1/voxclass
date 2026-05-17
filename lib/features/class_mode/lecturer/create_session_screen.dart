import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/session_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/supabase_service.dart';
import '../widgets/qr_display_widget.dart';

class CreateSessionScreen extends ConsumerStatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  ConsumerState<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends ConsumerState<CreateSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  bool _loading = false;
  SessionModel? _createdSession;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = await ref.read(authStateProvider.future);
      if (user == null) return;
      final session = await SupabaseService.createSession(
        lecturerId: user.id,
        title: _titleCtrl.text.trim(),
        subject: _subjectCtrl.text.trim().isEmpty
            ? null
            : _subjectCtrl.text.trim(),
      );
      setState(() => _createdSession = session);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textMuted, size: 18),
            onPressed: () => context.go('/dashboard'),
          ),
          title: Text(
            _createdSession == null ? 'New Session' : 'Session Ready',
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _createdSession == null
                ? _BuildForm(
                    formKey: _formKey,
                    titleCtrl: _titleCtrl,
                    subjectCtrl: _subjectCtrl,
                    loading: _loading,
                    onCreate: _create,
                  )
                : _SessionCreated(
                    session: _createdSession!,
                    onStartLive: () =>
                        context.go('/class/live/${_createdSession!.id}'),
                  ),
          ),
        ),
      ),
    );
  }
}

class _BuildForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController titleCtrl;
  final TextEditingController subjectCtrl;
  final bool loading;
  final VoidCallback onCreate;

  const _BuildForm({
    required this.formKey,
    required this.titleCtrl,
    required this.subjectCtrl,
    required this.loading,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.indigo.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.sensors, color: Colors.white, size: 28),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

          const SizedBox(height: 20),

          Text(
            'What are you\nteaching today?',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.15,
              letterSpacing: -0.8,
            ),
          ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.2),

          const SizedBox(height: 6),

          Text(
            'Students will join using the code generated for this session.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted, height: 1.5),
          ).animate().fadeIn(delay: 120.ms),

          const SizedBox(height: 36),

          // ── Session Title ─────────────────────────────────────────────
          Text(
            'Session Title',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500),
          ).animate().fadeIn(delay: 140.ms),
          const SizedBox(height: 8),
          TextFormField(
            controller: titleCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'e.g. Introduction to Machine Learning',
              prefixIcon: Icon(Icons.title_outlined, color: AppColors.textMuted),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Add a session title' : null,
          ).animate().fadeIn(delay: 160.ms).slideY(begin: 0.15),

          const SizedBox(height: 20),

          // ── Subject ───────────────────────────────────────────────────
          Text(
            'Subject / Course',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500),
          ).animate().fadeIn(delay: 180.ms),
          const SizedBox(height: 8),
          TextFormField(
            controller: subjectCtrl,
            decoration: const InputDecoration(
              hintText: 'e.g. CS301, Data Science  (optional)',
              prefixIcon: Icon(Icons.book_outlined, color: AppColors.textMuted),
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.15),

          const SizedBox(height: 36),

          // ── Info cards ─────────────────────────────────────────────────
          Row(
            children: [
              _InfoChip(icon: Icons.people_outline, label: 'Unlimited students'),
              const SizedBox(width: 10),
              _InfoChip(icon: Icons.lock_outline, label: 'Anonymous Q&A'),
              const SizedBox(width: 10),
              _InfoChip(icon: Icons.auto_awesome_outlined, label: 'Gemini AI'),
            ],
          ).animate().fadeIn(delay: 220.ms),

          const SizedBox(height: 32),

          // ── Create button ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.indigo.withValues(alpha: 0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: loading ? null : onCreate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50)),
                ),
                icon: loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sensors, size: 20),
                label: Text(
                  loading ? 'Creating session...' : 'Create & Get Code',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 260.ms),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: AppColors.indigo),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 9,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                  height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCreated extends StatelessWidget {
  final SessionModel session;
  final VoidCallback onStartLive;

  const _SessionCreated({required this.session, required this.onStartLive});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),

        // ── Success icon ─────────────────────────────────────────────────
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.green.withValues(alpha: 0.3), width: 2),
          ),
          child: const Icon(Icons.check_circle_outline,
              color: AppColors.green, size: 36),
        ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

        const SizedBox(height: 16),

        Text(
          'Session Created!',
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ).animate().fadeIn(delay: 150.ms),

        const SizedBox(height: 4),

        Text(
          session.title,
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 200.ms),

        const SizedBox(height: 28),

        QrDisplayWidget(
          code: session.code,
          sessionTitle: session.title,
        ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.15),

        const SizedBox(height: 28),

        // ── Go Live button ────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 56,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: AppColors.indigo.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: onStartLive,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50)),
              ),
              icon: const Icon(Icons.sensors, size: 20),
              label: Text(
                'Go Live Now →',
                style:
                    GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ).animate().fadeIn(delay: 350.ms),

        const SizedBox(height: 14),

        TextButton(
          onPressed: () => context.go('/dashboard'),
          child: Text(
            'Share later — go to dashboard',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textMuted),
          ),
        ).animate().fadeIn(delay: 420.ms),
      ],
    );
  }
}
