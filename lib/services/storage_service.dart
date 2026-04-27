import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

class StorageService {
  final _supabase = Supabase.instance.client;

  /// Uploads an image to the [bucket] and returns the public URL.
  Future<String?> uploadImage({
    required File file,
    required String bucket,
    required String pathPrefix,
  }) async {
    try {
      final ext = p.extension(file.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
      final filePath = '$pathPrefix/$fileName';

      await _supabase.storage.from(bucket).upload(filePath, file);

      final String publicUrl =
          _supabase.storage.from(bucket).getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      print('StorageService error: $e');
      return null;
    }
  }

  /// Removes an image from the [bucket].
  Future<bool> deleteImage({
    required String bucket,
    required String fileUrl,
  }) async {
    try {
      // fileUrl is typically: https://.../storage/v1/object/public/bucket/path/to/file.jpg
      // We need just 'path/to/file.jpg'
      final uri = Uri.parse(fileUrl);
      final segments = uri.pathSegments;
      final bucketIndex = segments.indexOf(bucket);
      if (bucketIndex != -1 && bucketIndex < segments.length - 1) {
        final filePath = segments.sublist(bucketIndex + 1).join('/');
        await _supabase.storage.from(bucket).remove([filePath]);
        return true;
      }
      return false;
    } catch (e) {
      print('StorageService delete error: $e');
      return false;
    }
  }
}
