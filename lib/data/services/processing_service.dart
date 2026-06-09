import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';

class ProcessingService {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Legacy batch pipeline — kept for reference, not used in streaming flow.
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
      throw Exception('Failed to start processing: ${response.status}');
    }
  }

  /// Streaming flow: saves transcript + generates summary via Edge Function.
  /// Fire-and-forget — caller should not await this.
  Future<void> generateSummary({
    required String noteId,
    required String fullText,
    required List<Map<String, dynamic>> segments,
  }) async {
    try {
      await _client.functions.invoke(
        'generate-summary',
        body: {
          'note_id': noteId,
          'full_text': fullText,
          'segments': segments,
        },
      );
    } catch (_) {
      // Non-critical — summary will just stay loading in NoteDetail
    }
  }
}
