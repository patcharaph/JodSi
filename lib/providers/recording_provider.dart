import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';
import '../data/models/note.dart';
import '../data/services/audio_recording_service.dart';
import 'service_providers.dart';
import 'notes_provider.dart';

enum RecordingState { idle, recording, uploading, processing }

class RecordingStatus {
  final RecordingState state;
  final int elapsedSeconds;
  final String? noteId;
  final String? errorMessage;
  final List<Bookmark> bookmarks;

  const RecordingStatus({
    this.state = RecordingState.idle,
    this.elapsedSeconds = 0,
    this.noteId,
    this.errorMessage,
    this.bookmarks = const [],
  });

  RecordingStatus copyWith({
    RecordingState? state,
    int? elapsedSeconds,
    String? noteId,
    String? errorMessage,
    List<Bookmark>? bookmarks,
  }) {
    return RecordingStatus(
      state: state ?? this.state,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      noteId: noteId ?? this.noteId,
      errorMessage: errorMessage,
      bookmarks: bookmarks ?? this.bookmarks,
    );
  }

  String get elapsedFormatted {
    final minutes = elapsedSeconds ~/ 60;
    final seconds = elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

final recordingProvider =
    StateNotifierProvider<RecordingNotifier, RecordingStatus>(
  (ref) => RecordingNotifier(ref),
);

class RecordingNotifier extends StateNotifier<RecordingStatus> {
  final Ref _ref;
  Timer? _timer;

  RecordingNotifier(this._ref) : super(const RecordingStatus());

  AudioRecordingService get _recorder =>
      _ref.read(audioRecordingServiceProvider);

  Future<bool> startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        state = state.copyWith(
          errorMessage: 'ไม่ได้รับสิทธิ์ในการอัดเสียง',
        );
        return false;
      }

      await _recorder.start();

      state = state.copyWith(
        state: RecordingState.recording,
        elapsedSeconds: 0,
        bookmarks: [],
        errorMessage: null,
      );

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (state.state == RecordingState.recording) {
          state = state.copyWith(
            elapsedSeconds: state.elapsedSeconds + 1,
          );
        }
      });

      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<String?> stopRecording() async {
    try {
      _timer?.cancel();
      _timer = null;

      final result = await _recorder.stop();

      state = state.copyWith(state: RecordingState.uploading);

      // Create note in DB
      final notesNotifier = _ref.read(notesListProvider.notifier);
      final note = await notesNotifier.createNote();

      state = state.copyWith(noteId: note.id);

      // Upload audio
      final storageService = _ref.read(storageServiceProvider);
      final audioUrl = await storageService.uploadAudio(
        filePath: result.filePath,
        noteId: note.id,
      );

      // Update note with audio URL and duration
      final dbService = _ref.read(databaseServiceProvider);
      await dbService.updateNote(note.id, {
        'audio_url': audioUrl,
        'duration_sec': result.durationSec,
        'status': NoteStatus.transcribing.name,
        'bookmarks': state.bookmarks.map((b) => b.toJson()).toList(),
      });

      state = state.copyWith(state: RecordingState.processing);

      // Trigger processing pipeline
      final processingService = _ref.read(processingServiceProvider);
      await processingService.processAudio(
        noteId: note.id,
        audioUrl: audioUrl,
      );

      // Increment recording count for soft prompt
      await _incrementRecordingCount();

      return note.id;
    } catch (e) {
      state = state.copyWith(
        state: RecordingState.idle,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  void addBookmark() {
    if (state.state != RecordingState.recording) return;
    final bookmark = Bookmark(
      timestampSec: state.elapsedSeconds.toDouble(),
    );
    state = state.copyWith(
      bookmarks: [...state.bookmarks, bookmark],
    );
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    state = const RecordingStatus();
  }

  Future<void> _incrementRecordingCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('recording_count') ?? 0;
    await prefs.setInt('recording_count', count + 1);
  }

  Future<bool> shouldShowSoftPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('recording_count') ?? 0;
    final dismissed = prefs.getBool('soft_prompt_dismissed') ?? false;
    return count >= AppConfig.softPromptAfterRecordings && !dismissed;
  }

  Future<void> dismissSoftPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soft_prompt_dismissed', true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
