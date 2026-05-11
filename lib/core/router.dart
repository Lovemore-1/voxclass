import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/class_mode/lecturer/create_session_screen.dart';
import '../features/class_mode/lecturer/live_session_screen.dart';
import '../features/class_mode/lecturer/session_summary_screen.dart';
import '../features/class_mode/student/join_session_screen.dart';
import '../features/class_mode/student/student_session_screen.dart';
import '../features/polish_mode/polish_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthChangeNotifier();
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/onboarding',
    refreshListenable: notifier,
    redirect: (context, state) {
      final user = Supabase.instance.client.auth.currentUser;
      final isAuthenticated = user != null;
      final loc = state.matchedLocation;

      const publicRoutes = ['/onboarding', '/login', '/signup'];
      final isPublic = publicRoutes.contains(loc);

      if (!isAuthenticated && !isPublic) return '/login';
      if (isAuthenticated && isPublic) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        pageBuilder: (_, state) => _fadePage(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _fadePage(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (_, state) => _fadePage(state, const SignupScreen()),
      ),
      GoRoute(
        path: '/dashboard',
        pageBuilder: (_, state) => _fadePage(state, const DashboardScreen()),
      ),
      GoRoute(
        path: '/class/create',
        pageBuilder: (_, state) => _slidePage(state, const CreateSessionScreen()),
      ),
      GoRoute(
        path: '/class/live/:sessionId',
        pageBuilder: (_, state) => _slidePage(
          state,
          LiveSessionScreen(sessionId: state.pathParameters['sessionId']!),
        ),
      ),
      GoRoute(
        path: '/class/summary/:sessionId',
        pageBuilder: (_, state) => _slidePage(
          state,
          SessionSummaryScreen(sessionId: state.pathParameters['sessionId']!),
        ),
      ),
      GoRoute(
        path: '/class/join',
        pageBuilder: (_, state) => _slidePage(state, const JoinSessionScreen()),
      ),
      GoRoute(
        path: '/class/student/:sessionId',
        pageBuilder: (_, state) => _slidePage(
          state,
          StudentSessionScreen(sessionId: state.pathParameters['sessionId']!),
        ),
      ),
      GoRoute(
        path: '/polish',
        pageBuilder: (_, state) => _slidePage(state, const PolishScreen()),
      ),
    ],
  );
});

class _AuthChangeNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _sub;

  _AuthChangeNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange
        .listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

CustomTransitionPage<void> _slidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (_, animation, __, child) {
      final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}
