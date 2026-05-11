import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../models/session_model.dart';
import '../models/reaction_model.dart';
import '../models/slide_model.dart';
import '../models/question_model.dart';

class SupabaseService {
  static final _client = Supabase.instance.client;

  // ─── Auth ────────────────────────────────────────────────────────────────

  static User? get currentUser => _client.auth.currentUser;

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) =>
      _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'role': role},
      );

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) =>
      _client.auth.signInWithPassword(email: email, password: password);

  static Future<void> signOut() => _client.auth.signOut();

  // ─── Profile ─────────────────────────────────────────────────────────────

  static Future<ProfileModel?> getProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return ProfileModel.fromJson(data);
  }

  // ─── Sessions ─────────────────────────────────────────────────────────────

  static Future<SessionModel> createSession({
    required String lecturerId,
    required String title,
    String? subject,
  }) async {
    final code = _generateCode();
    final data = await _client.from('sessions').insert({
      'lecturer_id': lecturerId,
      'title': title,
      'subject': subject,
      'code': code,
      'status': 'active',
    }).select().single();
    return SessionModel.fromJson(data);
  }

  static Future<void> endSession(String sessionId) async {
    await _client.from('sessions').update({
      'status': 'ended',
      'ended_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);
  }

  static Future<SessionModel?> getSessionByCode(String code) async {
    final data = await _client
        .from('sessions')
        .select()
        .eq('code', code.toUpperCase())
        .eq('status', 'active')
        .maybeSingle();
    if (data == null) return null;
    return SessionModel.fromJson(data);
  }

  static Future<SessionModel?> getSession(String sessionId) async {
    final data = await _client
        .from('sessions')
        .select()
        .eq('id', sessionId)
        .maybeSingle();
    if (data == null) return null;
    return SessionModel.fromJson(data);
  }

  static Future<List<SessionModel>> getLecturerSessions(String lecturerId) async {
    final data = await _client
        .from('sessions')
        .select()
        .eq('lecturer_id', lecturerId)
        .order('created_at', ascending: false)
        .limit(20);
    return (data as List).map((e) => SessionModel.fromJson(e)).toList();
  }

  // ─── Reactions ────────────────────────────────────────────────────────────

  static Future<void> addReaction({
    required String sessionId,
    required String type,
    String? studentId,
    required String studentName,
  }) async {
    await _client.from('reactions').insert({
      'session_id': sessionId,
      'student_id': studentId,
      'student_name': studentName,
      'type': type,
    });
  }

  static Stream<List<ReactionModel>> reactionsStream(String sessionId) {
    return _client
        .from('reactions')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId)
        .order('created_at', ascending: false)
        .map((data) => data.map(ReactionModel.fromJson).toList());
  }

  static Future<List<ReactionModel>> getSessionReactions(String sessionId) async {
    final data = await _client
        .from('reactions')
        .select()
        .eq('session_id', sessionId)
        .order('created_at');
    return (data as List).map((e) => ReactionModel.fromJson(e)).toList();
  }

  // ─── Slides ───────────────────────────────────────────────────────────────

  static Future<SlideModel> addSlide({
    required String sessionId,
    required String fileUrl,
    required String fileName,
    required int orderIndex,
  }) async {
    final data = await _client.from('slides').insert({
      'session_id': sessionId,
      'file_url': fileUrl,
      'file_name': fileName,
      'order_index': orderIndex,
    }).select().single();
    return SlideModel.fromJson(data);
  }

  static Future<List<SlideModel>> getSessionSlides(String sessionId) async {
    final data = await _client
        .from('slides')
        .select()
        .eq('session_id', sessionId)
        .order('order_index');
    return (data as List).map((e) => SlideModel.fromJson(e)).toList();
  }

  static Stream<List<SlideModel>> slidesStream(String sessionId) {
    return _client
        .from('slides')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId)
        .order('order_index')
        .map((data) => data.map(SlideModel.fromJson).toList());
  }

  // ─── Questions ────────────────────────────────────────────────────────────

  static Future<void> saveQuestions({
    required String sessionId,
    required List<String> questions,
    required String sourceType,
    String? slideId,
  }) async {
    final rows = questions.map((q) => {
          'session_id': sessionId,
          'slide_id': slideId,
          'question_text': q,
          'source_type': sourceType,
          'is_pushed': false,
        }).toList();
    await _client.from('ai_questions').insert(rows);
  }

  static Future<void> pushQuestion(String questionId) async {
    await _client
        .from('ai_questions')
        .update({'is_pushed': true}).eq('id', questionId);
  }

  static Stream<List<QuestionModel>> questionsStream(String sessionId) {
    return _client
        .from('ai_questions')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId)
        .order('created_at')
        .map((data) => data.map(QuestionModel.fromJson).toList());
  }

  static Stream<List<QuestionModel>> pushedQuestionsStream(String sessionId) {
    return _client
        .from('ai_questions')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId)
        .order('created_at')
        .map((data) => data
            .map((e) => QuestionModel.fromJson(e))
            .where((q) => q.isPushed)
            .toList());
  }

  static Future<void> submitResponse({
    required String questionId,
    required String responseText,
    String? studentId,
    required String studentName,
  }) async {
    await _client.from('question_responses').insert({
      'question_id': questionId,
      'student_id': studentId,
      'student_name': studentName,
      'response_text': responseText,
    });
  }

  // ─── Polish logs ──────────────────────────────────────────────────────────

  static Future<void> savePolishLog({
    required String userId,
    required String inputText,
    required String outputText,
    required String mode,
  }) async {
    await _client.from('polish_logs').insert({
      'user_id': userId,
      'input_text': inputText,
      'output_text': outputText,
      'mode': mode,
    });
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
