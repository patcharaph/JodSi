import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/api_log.dart';
import 'service_providers.dart';

final adminOverviewProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getOverviewStats();
});

final adminDailyStatsProvider = FutureProvider<List<DailyStats>>((ref) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getDailyStats();
});

final adminRecentLogsProvider = FutureProvider<List<ApiLog>>((ref) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getRecentLogs();
});

final adminErrorLogsProvider = FutureProvider<List<ApiLog>>((ref) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getErrorLogs();
});

final adminFeedbackProvider =
    FutureProvider<List<FeedbackItem>>((ref) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getAllFeedback();
});
