import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';
import '../core/l10n/app_localizations.dart';
import '../data/models/note.dart';
import '../data/services/audio_recording_service.dart';
import '../data/services/deepgram_streaming_service.dart';
import 'service_providers.dart';
import 'notes_provider.dart';
import 'locale_provider.dart';

enum RecordingState { idle, recording, uploading }

class RecordingStatus {
  final RecordingState state;
  final int elapsedSeconds;
  final String? noteId;
  final String? errorMessage;
  final List<Bookmark> bookmarks;
  final String interimText;
  final String finalText;

  const RecordingStatus({
    this.state = RecordingState.idle,
    this.elapsedSeconds = 0,
    this.noteId,
    this.errorMessage,
    this.bookmarks = const [],
    this.interimText = '',
    this.finalText = '',
  });

  RecordingStatus copyWith({
    RecordingState? state,
    int? elapsedSeconds,
    String? noteId,
    String? errorMessage,
    List<Bookmark>? bookmarks,
    String? interimText,
    String? finalText,
  }) {
    return RecordingStatus(
      state: state ?? this.state,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      noteId: noteId ?? this.noteId,
      errorMessage: errorMessage,
      bookmarks: bookmarks ?? this.bookmarks,
      interimText: interimText ?? this.interimText,
      finalText: finalText ?? this.finalText,
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
  StreamSubscription<DeepgramResult>? _deepgramSub;
  void Function()? onAutoStop;

  RecordingNotifier(this._ref) : super(const RecordingStatus());

  AudioRecordingService get _recorder =>
      _ref.read(audioRecordingServiceProvider);

  DeepgramStreamingService get _deepgram =>
      _ref.read(deepgramStreamingServiceProvider);

  Future<bool> startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        state = state.copyWith(errorMessage: 'ไม่ได้รับสิทธิ์ในการอัดเสียง');
        return false;
      }

      // Connect Deepgram WebSocket before starting the mic
      final locale = _ref.read(localeProvider);
      final deepgramLang = locale.language == AppLanguage.th ? 'th' : 'en-US';

      await _deepgram.connect(
        pcmStream: _recorder.pcmStream,
        language: deepgramLang,
      );

      // Subscribe to transcript results
      _deepgramSub = _deepgram.results.listen((result) {
        if (!mounted) return;
        if (result.isFinal) {
          final newFinal = state.finalText.isEmpty
              ? result.text
              : '${state.finalText} ${result.text}';
          state = state.copyWith(finalText: newFinal, interimText: '');
        } else {
          state = state.copyWith(interimText: result.text);
        }
      });

      // Start audio recording (PCM stream now flows to both file and Deepgram)
      await _recorder.start();

      state = state.copyWith(
        state: RecordingState.recording,
        elapsedSeconds: 0,
        bookmarks: [],
        errorMessage: null,
        interimText: '',
        finalText: '',
      );

      final maxSeconds = AppConfig.freeMaxRecordingMinutes * 60;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (state.state == RecordingState.recording) {
          final next = state.elapsedSeconds + 1;
          state = state.copyWith(elapsedSeconds: next);
          if (next >= maxSeconds) onAutoStop?.call();
        }
      });

      return true;
    } catch (e) {
      dev.log('[JodSi] startRecording ERROR: $e');
      await _deepgram.disconnect();
      state = state.copyWith(
        state: RecordingState.idle,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<String?> stopRecording() async {
    try {
      _timer?.cancel();
      _timer = null;

      // Stop sending PCM to file first
      final result = await _recorder.stop();
      dev.log('[JodSi] stopRecording: recorder stopped, file=${result.filePath}');

      // Signal Deepgram to flush + collect remaining finals
      await _deepgram.disconnect();
      await _deepgramSub?.cancel();
      _deepgramSub = null;

      final fullText = state.finalText.trim();
      dev.log('[JodSi] stopRecording: transcript length=${fullText.length}');

      final audioFile = File(result.filePath);
      if (!await audioFile.exists() || await audioFile.length() == 0) {
        dev.log('[JodSi] stopRecording: audio file missing or empty');
        state = state.copyWith(
          state: RecordingState.idle,
          errorMessage: 'Audio file missing or empty',
        );
        return null;
      }

      state = state.copyWith(state: RecordingState.uploading);

      // Create note + upload audio
      final notesNotifier = _ref.read(notesListProvider.notifier);
      final note = await notesNotifier.createNote();
      dev.log('[JodSi] stopRecording: note created id=${note.id}');

      final storageService = _ref.read(storageServiceProvider);
      final audioUrl = await storageService.uploadAudio(
        filePath: result.filePath,
        noteId: note.id,
      );
      dev.log('[JodSi] stopRecording: uploaded url=$audioUrl');

      // Cleanup local file
      try {
        await audioFile.delete();
      } catch (_) {}

      // Update note: attach audio, set status to summarizing
      final dbService = _ref.read(databaseServiceProvider);
      await dbService.updateNote(note.id, {
        'audio_url': audioUrl,
        'duration_sec': result.durationSec,
        'status': NoteStatus.summarizing.name,
        'bookmarks': state.bookmarks.map((b) => b.toJson()).toList(),
      });

      // Fire-and-forget summary generation (saves transcript + calls LLM)
      final processingService = _ref.read(processingServiceProvider);
      processingService.generateSummary(
        noteId: note.id,
        fullText: fullText,
        segments: const [],
      );
      dev.log('[JodSi] stopRecording: generate-summary fired');

      await _incrementRecordingCount();

      return note.id;
    } catch (e, stack) {
      dev.log('[JodSi] stopRecording ERROR: $e\n$stack');
      state = state.copyWith(
        state: RecordingState.idle,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  void addBookmark() {
    if (state.state != RecordingState.recording) return;
    final bookmark = Bookmark(timestampSec: state.elapsedSeconds.toDouble());
    state = state.copyWith(bookmarks: [...state.bookmarks, bookmark]);
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
    _deepgramSub?.cancel();
    super.dispose();
  }
}
