import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/services.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final processingServiceProvider = Provider<ProcessingService>((ref) {
  return ProcessingService();
});

final audioRecordingServiceProvider = Provider<AudioRecordingService>((ref) {
  final service = AudioRecordingService();
  ref.onDispose(() => service.dispose());
  return service;
});
