import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<List<int>>? _streamSub;
  final _amplitudeController = StreamController<double>.broadcast();
  String? _currentPath;
  DateTime? _startTime;
  IOSink? _fileSink;
  int _bytesWritten = 0;

  static const int _sampleRate = 16000;
  static const int _numChannels = 1;
  static const int _bitsPerSample = 16;

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
    _bytesWritten = 0;

    // Open file and write placeholder WAV header (44 bytes)
    final file = File(_currentPath!);
    _fileSink = file.openWrite();
    _fileSink!.add(Uint8List(44)); // placeholder header

    // Start streaming PCM data from mic
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: _numChannels,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceRecognition,
        ),
      ),
    );

    _isRecording = true;
    _startTime = DateTime.now();

    _streamSub = stream.listen((data) {
      if (_fileSink != null) {
        _fileSink!.add(data);
        _bytesWritten += data.length;

        // Calculate RMS amplitude from PCM data for waveform UI
        if (data.length >= 2) {
          double sumSquares = 0;
          int sampleCount = 0;
          final byteData = Uint8List.fromList(data);
          for (int i = 0; i < byteData.length - 1; i += 2) {
            final sample = byteData[i] | (byteData[i + 1] << 8);
            final signed = sample > 32767 ? sample - 65536 : sample;
            sumSquares += signed * signed;
            sampleCount++;
          }
          if (sampleCount > 0) {
            final rms = sqrt(sumSquares / sampleCount);
            // Apply stronger gain (16x) so normal speaking moves waveform more clearly.
            final normalized = (rms / 32768.0 * 16.0).clamp(0.0, 1.0);
            _amplitudeController.add(normalized);
          }
        }
      }
    });

    return _currentPath!;
  }

  Future<RecordingResult> stop() async {
    _streamSub?.cancel();
    _streamSub = null;

    await _recorder.stop();

    // Close file sink
    await _fileSink?.flush();
    await _fileSink?.close();
    _fileSink = null;

    _isRecording = false;

    final duration = _startTime != null
        ? DateTime.now().difference(_startTime!).inSeconds
        : 0;

    _startTime = null;

    // Write proper WAV header
    if (_currentPath != null) {
      await _writeWavHeader(_currentPath!, _bytesWritten);
    }

    return RecordingResult(
      filePath: _currentPath ?? '',
      durationSec: duration,
    );
  }

  Future<void> _writeWavHeader(String path, int dataSize) async {
    final file = File(path);
    final raf = await file.open(mode: FileMode.writeOnlyAppend);
    await raf.setPosition(0);

    final byteRate = _sampleRate * _numChannels * (_bitsPerSample ~/ 8);
    final blockAlign = _numChannels * (_bitsPerSample ~/ 8);
    final fileSize = dataSize + 36;

    final header = ByteData(44);
    // RIFF header
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57);  // W
    header.setUint8(9, 0x41);  // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    // fmt chunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // (space)
    header.setUint32(16, 16, Endian.little); // chunk size
    header.setUint16(20, 1, Endian.little);  // PCM format
    header.setUint16(22, _numChannels, Endian.little);
    header.setUint32(24, _sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, _bitsPerSample, Endian.little);
    // data chunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    await raf.writeFrom(header.buffer.asUint8List());
    await raf.close();
  }

  int get elapsedSeconds {
    if (_startTime == null) return 0;
    return DateTime.now().difference(_startTime!).inSeconds;
  }

  Future<void> dispose() async {
    _streamSub?.cancel();
    await _fileSink?.close();
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
