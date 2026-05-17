import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  static final _client = Supabase.instance.client;
  static const _bucket = 'slides';
  static const _uuid = Uuid();

  static Future<String> uploadSlide({
    required String sessionId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final ext = fileName.split('.').last.toLowerCase();
    final path = 'sessions/$sessionId/${_uuid.v4()}.$ext';

    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _mimeType(ext),
            upsert: false,
          ),
        );

    return _client.storage.from(_bucket).getPublicUrl(path);
  }

  static Future<Uint8List?> downloadSlide(String fileUrl) async {
    try {
      final path = _pathFromUrl(fileUrl);
      debugPrint('[VoxClass][Storage] Downloading slide path=$path');
      final bytes = await _client.storage.from(_bucket).download(path);
      debugPrint('[VoxClass][Storage] Downloaded ${bytes.length} bytes');
      return bytes;
    } catch (e) {
      debugPrint('[VoxClass][Storage] downloadSlide FAILED: $e');
      return null;
    }
  }

  static String _mimeType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      default:
        return 'application/octet-stream';
    }
  }

  /// Returns true for file extensions Gemini can analyse natively
  /// (images + PDFs). PPT/PPTX can be uploaded but won't auto-generate
  /// questions.
  static bool isAiAnalysable(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return const {'png', 'jpg', 'jpeg', 'webp', 'pdf'}.contains(ext);
  }

  static String mimeTypeFor(String fileName) =>
      _mimeType(fileName.split('.').last.toLowerCase());

  static Future<void> deleteSlide(String fileUrl) async {
    try {
      final path = _pathFromUrl(fileUrl);
      await _client.storage.from(_bucket).remove([path]);
    } catch (_) {
      // Ignore storage errors — the DB record will still be removed
    }
  }

  static String _pathFromUrl(String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf(_bucket);
    if (bucketIndex >= 0 && bucketIndex < segments.length - 1) {
      return segments.sublist(bucketIndex + 1).join('/');
    }
    return uri.path;
  }
}
