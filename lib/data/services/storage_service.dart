import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';
import '../../core/config/supabase_config.dart';

class StorageService {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<String> uploadAudio({
    required String filePath,
    required String noteId,
  }) async {
    final file = File(filePath);
    final storagePath = '$noteId/audio.wav';

    await _client.storage.from(AppConfig.audioBucket).upload(
          storagePath,
          file,
          fileOptions: const FileOptions(
            contentType: 'audio/wav',
            upsert: true,
          ),
        );

    final url = _client.storage
        .from(AppConfig.audioBucket)
        .getPublicUrl(storagePath);

    return url;
  }

  Future<void> deleteAudio(String noteId) async {
    final storagePath = '$noteId/audio.wav';
    await _client.storage.from(AppConfig.audioBucket).remove([storagePath]);
  }
}
