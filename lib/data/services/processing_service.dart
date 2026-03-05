import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';

class ProcessingService {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Calls the Edge Function to start the audio processing pipeline:
  /// 1. Send audio to Deepgram for transcription
  /// 2. Deepgram calls back on-transcription-done
  /// 3. on-transcription-done sends to Gemini for summary
  /// 4. Results saved to DB, Realtime notifies client
  Future<void> processAudio({
    required String noteId,
    required String audioUrl,
  }) async {
    final response = await _client.functions.invoke(
      'process-audio',
      body: {
        'note_id': noteId,
        'audio_url': audioUrl,
      },
    );

    if (response.status != 200) {
      throw Exception(
        'Failed to start processing: ${response.status}',
      );
    }
  }
}
