import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  AppConstants._();

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static const appName = 'VoxClass';
  static const appTagline = 'Give your class a voice.';

  static const sessionCodeLength = 6;

  static const reactionGreen = 'green';
  static const reactionYellow = 'yellow';
  static const reactionRed = 'red';

  static const roleStudent = 'student';
  static const roleLecturer = 'lecturer';

  static const polishSoften = 'soften';
  static const polishStrengthen = 'strengthen';
  static const polishAcademic = 'academic';
  static const polishSimplify = 'simplify';
}
