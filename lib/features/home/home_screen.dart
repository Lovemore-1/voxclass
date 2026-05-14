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
    _barControllers = List.generate(6, (i) {
      final ctrl = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + i * 120),
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
            Future.delayed(Duration(milliseconds: _random.nextInt(200)), () {
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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Logo icon
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.purple.withValues(alpha: 0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.auto_awesome, color: Colors.white, size: 40),
                    ),
                  ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

                  const SizedBox(height: 24),

                  Text(
                    'VoxClass',
                    style: GoogleFonts.inter(
                      fontSize: 32, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary, letterSpacing: -0.5,
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3),

                  const SizedBox(height: 8),

                  Text(
                    'Give Your Class a Voice',
                    style: GoogleFonts.inter(
                      fontSize: 16, color: AppColors.textMuted,
                      fontWeight: FontWeight.w400,
                    ),
                  ).animate().fadeIn(delay: 300.ms),

                  const Spacer(flex: 2),

                  // Join Session button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50)),
                      ),
                      icon: const Icon(Icons.group_outlined, size: 20),
                      label: Text('Join Session',
                          style: GoogleFonts.inter(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3),

                  const SizedBox(height: 14),

                  // Start Teaching button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.purpleGradient,
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.purple.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => context.go('/login'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50)),
                        ),
                        icon: const Icon(Icons.auto_fix_high_outlined, size: 20),
                        label: Text('Start Teaching',
                            style: GoogleFonts.inter(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ).animate().fadeIn(delay: 480.ms).slideY(begin: 0.3),

                  const Spacer(flex: 1),

                  // Animated sound bars
                  _SoundBars(controllers: _barControllers)
                      .animate().fadeIn(delay: 600.ms),

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

class _SoundBars extends StatelessWidget {
  final List<AnimationController> controllers;
  const _SoundBars({required this.controllers});

  static const _maxHeights = [20.0, 34.0, 44.0, 50.0, 38.0, 26.0];
  static const _minHeights = [8.0, 14.0, 18.0, 20.0, 14.0, 10.0];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(controllers.length, (i) {
        return AnimatedBuilder(
          animation: controllers[i],
          builder: (_, __) {
            final h = _minHeights[i] +
                (_maxHeights[i] - _minHeights[i]) * controllers[i].value;
            return Container(
              width: 5,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [AppColors.indigo, AppColors.purple],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          },
        );
      }),
    );
  }
}
