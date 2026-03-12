import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amplitudeSub;
  final _amplitudeController = StreamController<double>.broadcast();
  String? _currentPath;
  DateTime? _startTime;

  Stream<double> get amplitudeStream => _amplitudeController.stream;
  bool _isRecording = false;
  bool get isRecording => _isRecording;

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<String> start() async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentPath = p.join(dir.path, 'recording_$timestamp.wav');

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _currentPath!,
    );

    _isRecording = true;
    _startTime = DateTime.now();

    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((amp) {
      // Normalize amplitude from dB to 0.0 - 1.0
      // amp.current ranges from -160 to 0 dB
      final normalized = (amp.current + 60) / 60;
      _amplitudeController.add(normalized.clamp(0.0, 1.0));
    });

    return _currentPath!;
  }

  Future<RecordingResult> stop() async {
    _amplitudeSub?.cancel();
    _amplitudeSub = null;

    final path = await _recorder.stop();
    _isRecording = false;

    final duration = _startTime != null
        ? DateTime.now().difference(_startTime!).inSeconds
        : 0;

    _startTime = null;

    return RecordingResult(
      filePath: path ?? _currentPath ?? '',
      durationSec: duration,
    );
  }

  int get elapsedSeconds {
    if (_startTime == null) return 0;
    return DateTime.now().difference(_startTime!).inSeconds;
  }

  Future<void> dispose() async {
    _amplitudeSub?.cancel();
    await _amplitudeController.close();
    await _recorder.dispose();
  }
}

class RecordingResult {
  final String filePath;
  final int durationSec;

  const RecordingResult({
    required this.filePath,
    required this.durationSec,
  });
}
