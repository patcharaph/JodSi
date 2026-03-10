import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';
import '../../core/config/supabase_config.dart';
import '../models/api_log.dart';

class FeedbackService {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<void> submitFeedback({
    required String userId,
    required String type,
    required String message,
    String? noteId,
    int? rating,
    String? deviceInfo,
  }) async {
    await _client.from('feedback').insert({
      'user_id': userId,
      'note_id': noteId,
      'type': type,
      'rating': rating,
      'message': message,
      'app_version': AppConfig.appVersion,
      'device_info': deviceInfo,
    });
  }

  Future<List<FeedbackItem>> getMyFeedback(String userId) async {
    final response = await _client
        .from('feedback')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => FeedbackItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
