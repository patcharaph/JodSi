class ApiLog {
  final String id;
  final String functionName;
  final String? noteId;
  final String? userId;
  final String status;
  final int? statusCode;
  final String? errorMessage;
  final double deepgramCost;
  final double openrouterCost;
  final double totalCost;
  final int? durationMs;
  final int? audioDurationSec;
  final int? transcriptChars;
  final String? modelUsed;
  final DateTime createdAt;

  const ApiLog({
    required this.id,
    required this.functionName,
    this.noteId,
    this.userId,
    required this.status,
    this.statusCode,
    this.errorMessage,
    this.deepgramCost = 0,
    this.openrouterCost = 0,
    this.totalCost = 0,
    this.durationMs,
    this.audioDurationSec,
    this.transcriptChars,
    this.modelUsed,
    required this.createdAt,
  });

  bool get isError => status == 'error';

  factory ApiLog.fromJson(Map<String, dynamic> json) {
    return ApiLog(
      id: json['id'] as String,
      functionName: json['function_name'] as String,
      noteId: json['note_id'] as String?,
      userId: json['user_id'] as String?,
      status: json['status'] as String,
      statusCode: json['status_code'] as int?,
      errorMessage: json['error_message'] as String?,
      deepgramCost: (json['deepgram_cost'] as num?)?.toDouble() ?? 0,
      openrouterCost: (json['openrouter_cost'] as num?)?.toDouble() ?? 0,
      totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0,
      durationMs: json['duration_ms'] as int?,
      audioDurationSec: json['audio_duration_sec'] as int?,
      transcriptChars: json['transcript_chars'] as int?,
      modelUsed: json['model_used'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class DailyStats {
  final DateTime day;
  final int totalRequests;
  final int errorCount;
  final double totalCostUsd;
  final double deepgramCostUsd;
  final double openrouterCostUsd;
  final int avgDurationMs;
  final int totalAudioSec;
  final int uniqueUsers;

  const DailyStats({
    required this.day,
    required this.totalRequests,
    required this.errorCount,
    required this.totalCostUsd,
    required this.deepgramCostUsd,
    required this.openrouterCostUsd,
    required this.avgDurationMs,
    required this.totalAudioSec,
    required this.uniqueUsers,
  });

  double get errorRate =>
      totalRequests > 0 ? (errorCount / totalRequests) * 100 : 0;

  factory DailyStats.fromJson(Map<String, dynamic> json) {
    return DailyStats(
      day: DateTime.parse(json['day'] as String),
      totalRequests: (json['total_requests'] as num?)?.toInt() ?? 0,
      errorCount: (json['error_count'] as num?)?.toInt() ?? 0,
      totalCostUsd: (json['total_cost_usd'] as num?)?.toDouble() ?? 0,
      deepgramCostUsd: (json['deepgram_cost_usd'] as num?)?.toDouble() ?? 0,
      openrouterCostUsd:
          (json['openrouter_cost_usd'] as num?)?.toDouble() ?? 0,
      avgDurationMs: (json['avg_duration_ms'] as num?)?.toInt() ?? 0,
      totalAudioSec: (json['total_audio_sec'] as num?)?.toInt() ?? 0,
      uniqueUsers: (json['unique_users'] as num?)?.toInt() ?? 0,
    );
  }
}

class FeedbackItem {
  final String id;
  final String? userId;
  final String? noteId;
  final String type;
  final int? rating;
  final String message;
  final String? appVersion;
  final String? deviceInfo;
  final String status;
  final String? adminNotes;
  final DateTime createdAt;

  const FeedbackItem({
    required this.id,
    this.userId,
    this.noteId,
    required this.type,
    this.rating,
    required this.message,
    this.appVersion,
    this.deviceInfo,
    this.status = 'new',
    this.adminNotes,
    required this.createdAt,
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> json) {
    return FeedbackItem(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      noteId: json['note_id'] as String?,
      type: json['type'] as String? ?? 'general',
      rating: json['rating'] as int?,
      message: json['message'] as String,
      appVersion: json['app_version'] as String?,
      deviceInfo: json['device_info'] as String?,
      status: json['status'] as String? ?? 'new',
      adminNotes: json['admin_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
