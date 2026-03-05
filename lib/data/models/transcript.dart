class TranscriptSegment {
  final double start;
  final double end;
  final String text;

  const TranscriptSegment({
    required this.start,
    required this.end,
    required this.text,
  });

  String get startFormatted => _formatTimestamp(start);
  String get endFormatted => _formatTimestamp(end);

  static String _formatTimestamp(double seconds) {
    final mins = seconds ~/ 60;
    final secs = (seconds % 60).toInt();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptSegment(
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
      text: json['text'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
        'text': text,
      };
}

class Transcript {
  final String id;
  final String noteId;
  final List<TranscriptSegment> segments;
  final String? fullText;
  final Map<String, dynamic>? rawResponse;

  const Transcript({
    required this.id,
    required this.noteId,
    this.segments = const [],
    this.fullText,
    this.rawResponse,
  });

  factory Transcript.fromJson(Map<String, dynamic> json) {
    final segmentsJson = json['segments'] as List<dynamic>? ?? [];
    return Transcript(
      id: json['id'] as String,
      noteId: json['note_id'] as String,
      segments: segmentsJson
          .map((s) => TranscriptSegment.fromJson(s as Map<String, dynamic>))
          .toList(),
      fullText: json['full_text'] as String?,
      rawResponse: json['raw_response'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'note_id': noteId,
        'segments': segments.map((s) => s.toJson()).toList(),
        'full_text': fullText,
        'raw_response': rawResponse,
      };
}
