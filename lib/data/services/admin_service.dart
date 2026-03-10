import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../models/api_log.dart';

class AdminService {
  final SupabaseClient _client = SupabaseConfig.client;

  // ─── API Logs ───────────────────────────────────────────

  Future<List<ApiLog>> getRecentLogs({int limit = 50}) async {
    final response = await _client
        .from('api_logs')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => ApiLog.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<ApiLog>> getErrorLogs({int limit = 50}) async {
    final response = await _client
        .from('api_logs')
        .select()
        .eq('status', 'error')
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => ApiLog.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // ─── Daily Stats ────────────────────────────────────────

  Future<List<DailyStats>> getDailyStats({int days = 30}) async {
    final response = await _client
        .from('admin_daily_stats')
        .select()
        .limit(days);

    return (response as List)
        .map((json) => DailyStats.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // ─── Aggregated Summary ─────────────────────────────────

  Future<Map<String, dynamic>> getOverviewStats() async {
    final logs = await _client
        .from('api_logs')
        .select('status, total_cost, duration_ms')
        .order('created_at', ascending: false)
        .limit(500);

    final logList = logs as List;
    if (logList.isEmpty) {
      return {
        'totalRequests': 0,
        'errorCount': 0,
        'totalCost': 0.0,
        'avgDuration': 0,
      };
    }

    int errorCount = 0;
    double totalCost = 0;
    int totalDuration = 0;
    int durationCount = 0;

    for (final log in logList) {
      if (log['status'] == 'error') errorCount++;
      totalCost += (log['total_cost'] as num?)?.toDouble() ?? 0;
      final ms = log['duration_ms'] as int?;
      if (ms != null) {
        totalDuration += ms;
        durationCount++;
      }
    }

    return {
      'totalRequests': logList.length,
      'errorCount': errorCount,
      'totalCost': totalCost,
      'avgDuration': durationCount > 0 ? totalDuration ~/ durationCount : 0,
    };
  }

  // ─── Feedback Management ────────────────────────────────

  Future<List<FeedbackItem>> getAllFeedback({int limit = 50}) async {
    final response = await _client
        .from('feedback')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => FeedbackItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateFeedbackStatus(String feedbackId, String status,
      {String? adminNotes}) async {
    final data = <String, dynamic>{'status': status};
    if (adminNotes != null) data['admin_notes'] = adminNotes;
    await _client.from('feedback').update(data).eq('id', feedbackId);
  }
}
