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
        subject: _subjectCtrl.text.trim().isEmpty ? null : _subjectCtrl.text.trim(),
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        title: const Text('New Class Session'),
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
                  onStartLive: () => context.go('/class/live/${_createdSession!.id}'),
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
          Text(
            'What are you teaching\ntoday? 📚',
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.2,
              letterSpacing: -0.8,
            ),
          ).animate().fadeIn().slideY(begin: 0.2),
          const SizedBox(height: 32),
          Text(
            'Session Title',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 8),
          TextFormField(
            controller: titleCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'e.g. Introduction to Machine Learning',
              prefixIcon: Icon(Icons.title_outlined, color: AppColors.textMuted),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Add a session title' : null,
          ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.2),
          const SizedBox(height: 16),
          Text(
            'Subject / Course (optional)',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500),
          ).animate().fadeIn(delay: 140.ms),
          const SizedBox(height: 8),
          TextFormField(
            controller: subjectCtrl,
            decoration: const InputDecoration(
              hintText: 'e.g. CS301, Data Science',
              prefixIcon: Icon(Icons.book_outlined, color: AppColors.textMuted),
            ),
          ).animate().fadeIn(delay: 160.ms).slideY(begin: 0.2),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: loading ? null : onCreate,
              icon: loading
                  ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.darkBg),
                    )
                  : const Icon(Icons.sensors, size: 18),
              label: Text(loading ? 'Creating...' : 'Create Session'),
            ),
          ).animate().fadeIn(delay: 200.ms),
        ],
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
        Text(
          '🎉 Session Created!',
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
        const SizedBox(height: 6),
        Text(
          'Share this code with your students',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 32),
        QrDisplayWidget(
          code: session.code,
          sessionTitle: session.title,
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onStartLive,
            icon: const Icon(Icons.sensors, size: 18),
            label: const Text('Go Live Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lime,
              foregroundColor: AppColors.darkBg,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }
}
