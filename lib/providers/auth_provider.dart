import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../services/supabase_service.dart';

// Auth state — streams the current User or null
final authStateProvider = StreamProvider<User?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange
      .map((event) => event.session?.user);
});

// Current user's profile
final profileProvider = FutureProvider.autoDispose<ProfileModel?>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return null;
  return SupabaseService.getProfile(user.id);
});
