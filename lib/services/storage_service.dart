import 'dart:typed_data';
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
      return await _client.storage.from(_bucket).download(path);
    } catch (_) {
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
      default:
        return 'application/octet-stream';
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
