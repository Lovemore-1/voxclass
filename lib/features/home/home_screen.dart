import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final List<AnimationController> _barControllers;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _barControllers = List.generate(8, (i) {
      final ctrl = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 350 + i * 90),
      );
      _animateBar(ctrl);
      return ctrl;
    });
  }

  void _animateBar(AnimationController ctrl) {
    ctrl.forward().then((_) {
      if (mounted) {
        ctrl.reverse().then((_) {
          if (mounted) {
            Future.delayed(Duration(milliseconds: _random.nextInt(300) + 100), () {
              if (mounted) _animateBar(ctrl);
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    for (final c in _barControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 52),

                  // ── Badge pill ──────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.indigo.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: AppColors.indigo.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AI-Powered Classroom Technology',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.indigoLight,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 32),

                  // ── Logo icon ───────────────────────────────────────────
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.purple.withValues(alpha: 0.45),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        'assets/images/logo_icon.png',
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Center(
                            child: _SoundBars(
                                controllers: _barControllers, small: true),
                          ),
                        ),
                      ),
                    ),
                  ).animate().scale(duration: 700.ms, curve: Curves.elasticOut),

                  const SizedBox(height: 28),

                  // ── Full logo (with wordmark) ────────────────────────────
                  Image.asset(
                    'assets/images/logo_wordmark.png',
                    height: 52,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ).animate().fadeIn(delay: 180.ms),

                  const SizedBox(height: 12),

                  // ── Headline ────────────────────────────────────────────
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFFFFFF), Color(0xFFA78BFA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Text(
                      'Give Your\nClass a Voice',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                        letterSpacing: -1.5,
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

                  const SizedBox(height: 16),

                  Text(
                    'Real-time feedback, AI-generated questions,\nand anonymous student insights — all in one.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: AppColors.textMuted,
                      height: 1.6,
                    ),
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 40),

                  // ── Feature pills ───────────────────────────────────────
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: const [
                      _FeaturePill(icon: Icons.sensors_outlined, label: 'Live Reactions'),
                      _FeaturePill(icon: Icons.auto_awesome_outlined, label: 'AI Questions'),
                      _FeaturePill(icon: Icons.forum_outlined, label: 'Anon Q&A'),
                      _FeaturePill(icon: Icons.auto_fix_high_outlined, label: 'Text Polish'),
                    ],
                  ).animate().fadeIn(delay: 400.ms),

                  const SizedBox(height: 48),

                  // ── Primary CTA ─────────────────────────────────────────
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
                            color: AppColors.indigo.withValues(alpha: 0.45),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
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
                          'Get Started — It\'s Free',
                          style: GoogleFonts.inter(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3),

                  const SizedBox(height: 14),

                  // ── Secondary CTA ───────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/login'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50)),
                      ),
                      icon: const Icon(Icons.group_outlined, size: 20),
                      label: Text(
                        'Join a Session',
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ).animate().fadeIn(delay: 560.ms).slideY(begin: 0.3),

                  const SizedBox(height: 56),

                  // ── Feature row ─────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(child: _MiniFeatureCard(
                        icon: Icons.bolt_outlined,
                        iconColor: AppColors.amber,
                        title: 'Instant Setup',
                        subtitle: 'Create a session in seconds',
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _MiniFeatureCard(
                        icon: Icons.lock_outline,
                        iconColor: AppColors.green,
                        title: 'Anonymous Safe',
                        subtitle: 'Students ask without fear',
                      )),
                    ],
                  ).animate().fadeIn(delay: 650.ms).slideY(begin: 0.2),

                  const SizedBox(height: 12),

                  _MiniFeatureCard(
                    icon: Icons.auto_awesome_outlined,
                    iconColor: AppColors.purple,
                    title: 'Gemini AI Built-In',
                    subtitle: 'Auto-generate questions and re-explanations from your slides',
                    fullWidth: true,
                  ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2),

                  const SizedBox(height: 48),

                  // ── Footer ──────────────────────────────────────────────
                  Text(
                    'Made for educators who care about every student.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textMuted),
                  ).animate().fadeIn(delay: 750.ms),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Feature pill chip ──────────────────────────────────────────────────────────

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.indigo),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mini feature card ──────────────────────────────────────────────────────────

class _MiniFeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool fullWidth;

  const _MiniFeatureCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated sound bars (inside logo) ──────────────────────────────────────────

class _SoundBars extends StatelessWidget {
  final List<AnimationController> controllers;
  final bool small;
  const _SoundBars({required this.controllers, this.small = false});

  static const _maxH = [10.0, 18.0, 26.0, 30.0, 22.0, 16.0, 20.0, 12.0];
  static const _minH = [4.0, 7.0, 10.0, 12.0, 8.0, 6.0, 8.0, 5.0];

  @override
  Widget build(BuildContext context) {
    final count = controllers.length.clamp(0, _maxH.length);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(count, (i) {
        return AnimatedBuilder(
          animation: controllers[i],
          builder: (_, __) {
            final h = _minH[i] + (_maxH[i] - _minH[i]) * controllers[i].value;
            return Container(
              width: small ? 3.5 : 5,
              height: h,
              margin: EdgeInsets.symmetric(horizontal: small ? 1.5 : 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          },
        );
      }),
    );
  }
}
