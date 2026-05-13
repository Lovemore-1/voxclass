import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session_model.dart';
import '../models/reaction_model.dart';
import '../models/question_model.dart';
import '../models/slide_model.dart';
import '../models/anon_question_model.dart';
import '../services/supabase_service.dart';
import 'auth_provider.dart';

// Live reactions stream for a session
final reactionsStreamProvider =
    StreamProvider.family<List<ReactionModel>, String>((ref, sessionId) {
  return SupabaseService.reactionsStream(sessionId);
});

// Live slides stream
final slidesStreamProvider =
    StreamProvider.family<List<SlideModel>, String>((ref, sessionId) {
  return SupabaseService.slidesStream(sessionId);
});

// All questions for a session
final questionsStreamProvider =
    StreamProvider.family<List<QuestionModel>, String>((ref, sessionId) {
  return SupabaseService.questionsStream(sessionId);
});

// Only pushed questions (for students)
final pushedQuestionsStreamProvider =
    StreamProvider.family<List<QuestionModel>, String>((ref, sessionId) {
  return SupabaseService.pushedQuestionsStream(sessionId);
});

// Anonymous questions stream
final anonQuestionsStreamProvider =
    StreamProvider.family<List<AnonQuestionModel>, String>((ref, sessionId) {
  return SupabaseService.anonQuestionsStream(sessionId);
});

// Lecturer's session list
final lecturerSessionsProvider =
    FutureProvider.autoDispose<List<SessionModel>>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return [];
  return SupabaseService.getLecturerSessions(user.id);
});

// Single session details
final sessionProvider =
    FutureProvider.autoDispose.family<SessionModel?, String>((ref, sessionId) {
  return SupabaseService.getSession(sessionId);
});

// Helper: compute reaction counts from a list
({int green, int yellow, int red, int total}) computeReactionCounts(
    List<ReactionModel> reactions) {
  final green = reactions.where((r) => r.isGreen).length;
  final yellow = reactions.where((r) => r.isYellow).length;
  final red = reactions.where((r) => r.isRed).length;
  return (green: green, yellow: yellow, red: red, total: reactions.length);
}
