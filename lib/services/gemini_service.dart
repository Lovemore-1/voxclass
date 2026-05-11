import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/constants.dart';

class GeminiService {
  late final GenerativeModel _model;
  late final GenerativeModel _visionModel;

  GeminiService() {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: AppConstants.geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 1024,
      ),
    );
    _visionModel = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: AppConstants.geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.5,
        maxOutputTokens: 2048,
      ),
    );
  }

  // ─── Polish Mode ──────────────────────────────────────────────────────────

  Future<String> polishText({
    required String text,
    required String mode,
  }) async {
    final prompt = _polishPrompt(text, mode);
    final response = await _model.generateContent([Content.text(prompt)]);
    return response.text?.trim() ?? text;
  }

  String _polishPrompt(String text, String mode) {
    switch (mode) {
      case 'soften':
        return '''Rewrite the following feedback to be more constructive, empathetic, and encouraging while keeping the core message intact. Use a warm, supportive tone. Return ONLY the rewritten text with no preamble or explanation:

$text''';
      case 'strengthen':
        return '''Improve the following essay or writing with stronger arguments, better logical structure, more impactful language, and clearer thesis development. Return ONLY the rewritten text with no preamble:

$text''';
      case 'academic':
        return '''Rewrite the following text in formal academic style: precise vocabulary, third-person perspective where appropriate, proper scholarly tone, and structured argumentation. Return ONLY the rewritten text with no preamble:

$text''';
      case 'simplify':
        return '''Rewrite the following text in simple, clear, everyday language that anyone can understand. Use short sentences, common words, and direct phrasing. Return ONLY the rewritten text with no preamble:

$text''';
      default:
        return text;
    }
  }

  // ─── Slide Questions ──────────────────────────────────────────────────────

  Future<List<String>> generateQuestionsFromImage(Uint8List imageBytes) async {
    const prompt = '''You are an educational AI assistant helping a lecturer engage students.
Analyze this slide image and generate exactly 3 thought-provoking quiz questions to check student understanding of the content shown.
Return ONLY a JSON array of 3 strings, nothing else. Example format:
["Question 1?", "Question 2?", "Question 3?"]''';

    try {
      final response = await _visionModel.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ]);

      final raw = response.text?.trim() ?? '[]';
      final cleaned = raw.replaceAll('```json', '').replaceAll('```', '').trim();
      final parsed = jsonDecode(cleaned) as List;
      return parsed.cast<String>();
    } catch (e) {
      return [
        'What are the key concepts presented in this slide?',
        'How does this content relate to real-world applications?',
        'What questions do you have about this material?',
      ];
    }
  }

  // ─── Confused-Student Questions ───────────────────────────────────────────

  Future<List<String>> generateClarifyingQuestions({
    required String sessionTitle,
    required String? subject,
    required int confusedCount,
    required int totalStudents,
  }) async {
    final topic = subject != null ? '$sessionTitle ($subject)' : sessionTitle;
    final prompt = '''$confusedCount out of $totalStudents students have indicated they are confused or lost during a lecture on "$topic".

Generate exactly 3 targeted clarifying questions that a lecturer should ask the class to:
1. Identify specific gaps in understanding
2. Re-engage confused students
3. Check whether the core concept has been grasped

Make the questions specific, pedagogically sound, and appropriate for a university-level audience.
Return ONLY a JSON array of 3 strings, nothing else:
["Question 1?", "Question 2?", "Question 3?"]''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final raw = response.text?.trim() ?? '[]';
      final cleaned = raw.replaceAll('```json', '').replaceAll('```', '').trim();
      final parsed = jsonDecode(cleaned) as List;
      return parsed.cast<String>();
    } catch (e) {
      return [
        'Can you tell me which part of the explanation was unclear?',
        'Let\'s recap — what do you understand so far about this topic?',
        'What would help you understand this concept better right now?',
      ];
    }
  }

  // ─── Session Summary Insights ─────────────────────────────────────────────

  Future<String> generateSessionInsights({
    required String sessionTitle,
    required int greenCount,
    required int yellowCount,
    required int redCount,
  }) async {
    final total = greenCount + yellowCount + redCount;
    if (total == 0) return 'No reaction data available for this session.';

    final prompt = '''Analyze this classroom engagement data and provide a brief 2-3 sentence insight for the lecturer:

Session: "$sessionTitle"
Students who understood (🟢): $greenCount
Students who needed slower pace (🟡): $yellowCount
Students who were lost (🔴): $redCount
Total reactions: $total

Provide actionable, constructive insights. Return ONLY the insight text, no bullet points or headers.''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? 'Session completed successfully.';
    } catch (e) {
      return 'Session data recorded. Review the reaction breakdown for insights.';
    }
  }
}
