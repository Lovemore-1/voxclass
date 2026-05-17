import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
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

  // ─── Retry helper ─────────────────────────────────────────────────────────
  // Retries up to [maxAttempts] times with exponential backoff.
  // Rethrows on final failure so callers can fall back to safe defaults.

  Future<T> _withRetry<T>(
    Future<T> Function() fn, {
    int maxAttempts = 3,
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await fn();
      } catch (e) {
        if (attempt == maxAttempts) rethrow;
        // 500ms, 1000ms, 1500ms …
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
    throw Exception('Max retries exceeded');
  }

  // ─── Polish Mode ──────────────────────────────────────────────────────────

  Future<String> polishText({
    required String text,
    required String mode,
  }) async {
    final prompt = _polishPrompt(text, mode);
    try {
      return await _withRetry(() async {
        final response = await _model.generateContent([Content.text(prompt)]);
        return response.text?.trim() ?? text;
      });
    } catch (_) {
      return text;
    }
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

  Future<List<String>> generateQuestionsFromImage(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    const prompt =
        '''You are an educational AI assistant helping a lecturer engage students.
Analyze this slide (which may be an image or a PDF document) and generate exactly 3 thought-provoking quiz questions to check student understanding of the content shown.
Return ONLY a JSON array of 3 strings, nothing else. Example format:
["Question 1?", "Question 2?", "Question 3?"]''';

    try {
      return await _withRetry(() async {
        final response = await _visionModel.generateContent([
          Content.multi([
            TextPart(prompt),
            DataPart(mimeType, imageBytes),
          ])
        ]);
        final raw = response.text?.trim() ?? '[]';
        final cleaned =
            raw.replaceAll('```json', '').replaceAll('```', '').trim();
        final parsed = jsonDecode(cleaned) as List;
        return parsed.cast<String>();
      });
    } catch (_) {
      return [
        'What are the key concepts presented in this slide?',
        'How does this content relate to real-world applications?',
        'What questions do you have about this material?',
      ];
    }
  }

  // ─── Topic-based Questions (text-only, for PPTX / non-image slides) ─────────

  Future<List<String>> generateQuestionsForTopic({
    required String sessionTitle,
    String? subject,
    String? context,
  }) async {
    final topic = subject != null ? '$sessionTitle ($subject)' : sessionTitle;
    final extra = (context != null && context != sessionTitle)
        ? ' The slide or material is titled "$context".'
        : '';
    final prompt =
        '''You are an educational AI assistant helping a lecturer engage students.
Generate exactly 3 thought-provoking quiz questions for a lecture on "$topic".$extra
Questions should check student understanding and encourage critical thinking.
Return ONLY a JSON array of 3 strings, nothing else. Example format:
["Question 1?", "Question 2?", "Question 3?"]''';

    try {
      return await _withRetry(() async {
        final response = await _model.generateContent([Content.text(prompt)]);
        final raw = response.text?.trim() ?? '[]';
        final cleaned =
            raw.replaceAll('```json', '').replaceAll('```', '').trim();
        final parsed = jsonDecode(cleaned) as List;
        return parsed.cast<String>();
      });
    } catch (_) {
      return [
        'What are the key concepts covered so far?',
        'How would you apply this material in a real-world scenario?',
        'What questions do you still have about this topic?',
      ];
    }
  }

  // ─── Confused-Student Questions ───────────────────────────────────────────

  Future<List<String>> generateClarifyingQuestions({
    required String sessionTitle,
    required String? subject,
    required int confusedCount,
    required int totalStudents,
    Uint8List? slideBytes,
    String? slideMimeType,
  }) async {
    final topic =
        subject != null ? '$sessionTitle ($subject)' : sessionTitle;
    final prompt =
        '''$confusedCount out of $totalStudents students have indicated they are confused or lost during a lecture on "$topic".
${slideBytes != null ? 'The current slide is shown in the attached image — base your questions specifically on its content.' : ''}

Generate exactly 3 targeted clarifying questions that a lecturer should ask the class to:
1. Identify specific gaps in understanding
2. Re-engage confused students
3. Check whether the core concept has been grasped

Make the questions specific, pedagogically sound, and appropriate for a university-level audience.
Return ONLY a JSON array of 3 strings, nothing else:
["Question 1?", "Question 2?", "Question 3?"]''';

    try {
      return await _withRetry(() async {
        final content = slideBytes != null
            ? Content.multi([TextPart(prompt), DataPart(slideMimeType ?? 'image/jpeg', slideBytes)])
            : Content.text(prompt);
        final response = await _visionModel.generateContent([content]);
        final raw = response.text?.trim() ?? '[]';
        final cleaned =
            raw.replaceAll('```json', '').replaceAll('```', '').trim();
        final parsed = jsonDecode(cleaned) as List;
        return parsed.cast<String>();
      });
    } catch (_) {
      return [
        'Can you tell me which part of the explanation was unclear?',
        'Let\'s recap — what do you understand so far about this topic?',
        'What would help you understand this concept better right now?',
      ];
    }
  }

  // ─── Anonymous Question Clustering ───────────────────────────────────────

  Future<List<Map<String, dynamic>>> clusterAnonymousQuestions(
      List<String> questions) async {
    if (questions.isEmpty) return [];
    final numbered = questions
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');
    final prompt =
        '''You have ${questions.length} anonymous questions from students in a live lecture:\n$numbered\n\nGroup these into 1-4 themes. For each theme return:\n- "theme": the common confusion (short phrase)\n- "count": number of questions in this theme\n- "sample": the clearest example question\n\nReturn ONLY a JSON array:\n[{"theme":"...","count":2,"sample":"..."}]''';
    try {
      return await _withRetry(() async {
        final response =
            await _model.generateContent([Content.text(prompt)]);
        final raw = response.text?.trim() ?? '[]';
        final cleaned =
            raw.replaceAll('```json', '').replaceAll('```', '').trim();
        return (jsonDecode(cleaned) as List).cast<Map<String, dynamic>>();
      });
    } catch (_) {
      return [
        {
          'theme': 'General questions from students',
          'count': questions.length,
          'sample': questions.first,
        }
      ];
    }
  }

  // ─── Re-explain Generator ─────────────────────────────────────────────────

  Future<List<Map<String, String>>> generateReexplanations({
    required String topic,
    String? subject,
    Uint8List? slideBytes,
    String? slideMimeType,
  }) async {
    final ctx = subject != null ? '$topic ($subject)' : topic;
    final prompt =
        '''Students are confused about "$ctx" during a lecture.${slideBytes != null ? ' The current slide is attached — base your re-explanations on what is shown on it.' : ''}\n\nGenerate 3 re-explanations, each using a different style:\n1. "analogy" — a familiar real-world analogy\n2. "steps" — numbered step-by-step breakdown\n3. "example" — a concrete specific example\n\nReturn ONLY JSON:\n{"analogy":"...","steps":"...","example":"..."}''';
    try {
      return await _withRetry(() async {
        final content = slideBytes != null
            ? Content.multi([TextPart(prompt), DataPart(slideMimeType ?? 'image/jpeg', slideBytes)])
            : Content.text(prompt);
        debugPrint('[VoxClass][Gemini] generateReexplanations → calling API (hasSlide=${slideBytes != null})');
        final response = await _visionModel.generateContent([content]);
        final raw = response.text?.trim() ?? '{}';
        debugPrint('[VoxClass][Gemini] raw response: $raw');
        // Strip markdown fences and extract just the JSON object
        String cleaned = raw
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        // Find the first { ... } block in case Gemini adds prose around it
        final start = cleaned.indexOf('{');
        final end = cleaned.lastIndexOf('}');
        if (start != -1 && end != -1 && end > start) {
          cleaned = cleaned.substring(start, end + 1);
        }
        debugPrint('[VoxClass][Gemini] cleaned JSON: $cleaned');
        final p = jsonDecode(cleaned) as Map<String, dynamic>;
        return [
          {'type': 'analogy',  'label': 'Analogy',         'text': p['analogy']  as String? ?? ''},
          {'type': 'steps',    'label': 'Step by Step',    'text': p['steps']    as String? ?? ''},
          {'type': 'example',  'label': 'Concrete Example','text': p['example']  as String? ?? ''},
        ];
      });
    } catch (e) {
      debugPrint('[VoxClass][Gemini] generateReexplanations FAILED: $e');
      final errMsg = 'Error: $e';
      return [
        {'type': 'analogy',  'label': 'Analogy',         'text': errMsg},
        {'type': 'steps',    'label': 'Step by Step',    'text': errMsg},
        {'type': 'example',  'label': 'Concrete Example','text': errMsg},
      ];
    }
  }

  // ─── Session DNA (Teaching Pattern Analysis) ──────────────────────────────

  Future<String> analyzeTeachingPatterns(
      List<Map<String, dynamic>> sessionsData) async {
    if (sessionsData.isEmpty) return 'No session data available yet.';
    final lines = sessionsData.map((s) =>
        'Session "${s['title']}": ${s['green']} understood, ${s['yellow']} unsure, ${s['red']} lost (${s['total']} total reactions)');
    final prompt =
        "Analyze classroom engagement across ${sessionsData.length} sessions:\n\n${lines.join('\n')}\n\nProvide 2-3 specific, actionable insights for the lecturer. Look for confusion patterns, trends, and what's working. Return ONLY the insight text — no bullet points, no headers, just 2-3 sentences.";
    try {
      return await _withRetry(() async {
        final response =
            await _model.generateContent([Content.text(prompt)]);
        return response.text?.trim() ??
            'Run more sessions to generate pattern insights.';
      });
    } catch (_) {
      return 'Analysis unavailable. Ensure your Gemini API key is active.';
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

    final prompt =
        '''Analyze this classroom engagement data and provide a brief 2-3 sentence insight for the lecturer:

Session: "$sessionTitle"
Students who understood (🟢): $greenCount
Students who needed slower pace (🟡): $yellowCount
Students who were lost (🔴): $redCount
Total reactions: $total

Provide actionable, constructive insights. Return ONLY the insight text, no bullet points or headers.''';

    try {
      return await _withRetry(() async {
        final response =
            await _model.generateContent([Content.text(prompt)]);
        return response.text?.trim() ?? 'Session completed successfully.';
      });
    } catch (_) {
      return 'Session data recorded. Review the reaction breakdown for insights.';
    }
  }

  // ─── Question Answer (for students after they respond) ───────────────────

  Future<String> generateQuestionAnswer({
    required String questionText,
    required String sessionTitle,
    String? subject,
  }) async {
    final prompt = '''A student was asked this question during a live class session on "$sessionTitle"${subject != null ? ' ($subject)' : ''}:

"$questionText"

Provide a clear, concise correct answer in 2-4 sentences. Make it educational and easy to understand. Return ONLY the answer — no preamble.''';

    try {
      return await _withRetry(() async {
        final response = await _model.generateContent([Content.text(prompt)]);
        return response.text?.trim() ??
            'Great question! Review your notes or ask your lecturer for the answer.';
      });
    } catch (_) {
      return 'Review your course materials for the answer to this question.';
    }
  }
}
