import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/profile_model.dart';
import '../services/supabase_service.dart';

// Auth state — streams the current User or null
final authStateProvider = StreamProvider<User?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange
      .map((event) => event.session?.user);
});

// Current user's profile.
// Self-healing: if the auth user exists but the profiles row is missing
// (e.g. email confirmation is disabled and no DB trigger created it),
// we create it from the sign-up metadata.
final profileProvider = FutureProvider.autoDispose<ProfileModel?>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return null;

  final existing = await SupabaseService.getProfile(user.id);
  if (existing != null) return existing;

  // Try to recover full_name / role from the user metadata Supabase stored
  // on sign-up (passed via the `data:` parameter to signUp).
  final meta = user.userMetadata ?? <String, dynamic>{};
  final fullName = (meta['full_name'] as String?)?.trim();
  final role = (meta['role'] as String?)?.trim();

  // Last-resort sensible defaults so the user can still get into the app.
  final resolvedName = (fullName == null || fullName.isEmpty)
      ? (user.email?.split('@').first ?? 'User')
      : fullName;
  final resolvedRole = (role == AppConstants.roleLecturer ||
          role == AppConstants.roleStudent)
      ? role!
      : AppConstants.roleStudent;

  try {
    return await SupabaseService.ensureProfile(
      userId: user.id,
      fullName: resolvedName,
      role: resolvedRole,
    );
  } catch (_) {
    return null;
  }
});
