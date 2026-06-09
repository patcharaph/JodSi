import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../core/config/supabase_config.dart';

class DeepgramResult {
  final String text;
  final bool isFinal;

  const DeepgramResult({required this.text, required this.isFinal});
}

class DeepgramStreamingService {
  WebSocket? _ws;
  StreamSubscription<List<int>>? _pcmSub;
  final _resultController = StreamController<DeepgramResult>.broadcast();

  Stream<DeepgramResult> get results => _resultController.stream;
  bool _connected = false;

  Future<void> connect({
    required Stream<List<int>> pcmStream,
    required String language,
  }) async {
    // Fetch a short-lived token from our Edge Function
    final response = await SupabaseConfig.client.functions.invoke(
      'deepgram-token',
    );
    if (response.status != 200) {
      throw Exception('Failed to get Deepgram token: ${response.status}');
    }
    final token = (response.data as Map<String, dynamic>)['token'] as String;

    // Build WebSocket URL — auth via access_token query param works on all platforms
    final uri = Uri(
      scheme: 'wss',
      host: 'api.deepgram.com',
      path: '/v1/listen',
      queryParameters: {
        'access_token': token,
        'model': 'nova-2',
        'language': language,
        'encoding': 'linear16',
        'sample_rate': '16000',
        'channels': '1',
        'interim_results': 'true',
        'endpointing': '500',
        'smart_format': 'true',
      },
    );

    _ws = await WebSocket.connect(uri.toString());
    _connected = true;

    _ws!.listen(
      (data) {
        if (data is String) _handleMessage(data);
      },
      onError: (Object e) {
        if (!_resultController.isClosed) _resultController.addError(e);
      },
      onDone: () {
        _connected = false;
      },
      cancelOnError: false,
    );

    // Stream PCM chunks to Deepgram
    _pcmSub = pcmStream.listen((chunk) {
      if (_connected && _ws?.readyState == WebSocket.open) {
        _ws!.add(Uint8List.fromList(chunk));
      }
    });
  }

  void _handleMessage(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      if (json['type'] != 'Results') return;

      final isFinal = json['is_final'] as bool? ?? false;
      final alternatives =
          (json['channel'] as Map<String, dynamic>?)?['alternatives'] as List?;
      final transcript =
          alternatives?.firstOrNull?['transcript'] as String? ?? '';

      if (transcript.isEmpty) return;

      if (!_resultController.isClosed) {
        _resultController.add(DeepgramResult(text: transcript, isFinal: isFinal));
      }
    } catch (_) {}
  }

  // Call after stopping the recorder. Signals Deepgram to flush remaining audio,
  // then waits briefly for any last finals before closing.
  Future<void> disconnect() async {
    await _pcmSub?.cancel();
    _pcmSub = null;

    if (_ws != null && _ws!.readyState == WebSocket.open) {
      // Empty binary message tells Deepgram no more audio is coming
      try {
        _ws!.add(Uint8List(0));
      } catch (_) {}
      // Give Deepgram time to flush and send remaining finals
      await Future.delayed(const Duration(milliseconds: 1500));
      try {
        await _ws!.close();
      } catch (_) {}
    }

    _ws = null;
    _connected = false;
  }

  Future<void> dispose() async {
    await disconnect();
    if (!_resultController.isClosed) await _resultController.close();
  }
}
