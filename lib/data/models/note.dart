class Bookmark {
  final double timestampSec;
  final String? label;

  const Bookmark({required this.timestampSec, this.label});

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      timestampSec: (json['timestamp_sec'] as num).toDouble(),
      label: json['label'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'timestamp_sec': timestampSec,
        'label': label,
      };
}

enum NoteStatus {
  recording,
  uploading,
  transcribing,
  summarizing,
  done,
  error;

  static NoteStatus fromString(String value) {
    return NoteStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NoteStatus.error,
    );
  }
}

class Note {
  final String id;
  final String userId;
  final String? title;
  final String? audioUrl;
  final int? durationSec;
  final NoteStatus status;
  final List<Bookmark> bookmarks;
  final DateTime createdAt;

  const Note({
    required this.id,
    required this.userId,
    this.title,
    this.audioUrl,
    this.durationSec,
    this.status = NoteStatus.recording,
    this.bookmarks = const [],
    required this.createdAt,
  });

  String get displayTitle => title ?? 'โน้ตไม่มีชื่อ';

  String get durationFormatted {
    if (durationSec == null) return '--:--';
    final minutes = durationSec! ~/ 60;
    final seconds = durationSec! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  bool get isProcessing =>
      status == NoteStatus.uploading ||
      status == NoteStatus.transcribing ||
      status == NoteStatus.summarizing;

  factory Note.fromJson(Map<String, dynamic> json) {
    final bookmarksJson = json['bookmarks'] as List<dynamic>? ?? [];
    return Note(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String?,
      audioUrl: json['audio_url'] as String?,
      durationSec: json['duration_sec'] as int?,
      status: NoteStatus.fromString(json['status'] as String? ?? 'recording'),
      bookmarks: bookmarksJson
          .map((b) => Bookmark.fromJson(b as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'audio_url': audioUrl,
        'duration_sec': durationSec,
        'status': status.name,
        'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };

  Note copyWith({
    String? title,
    String? audioUrl,
    int? durationSec,
    NoteStatus? status,
    List<Bookmark>? bookmarks,
  }) {
    return Note(
      id: id,
      userId: userId,
      title: title ?? this.title,
      audioUrl: audioUrl ?? this.audioUrl,
      durationSec: durationSec ?? this.durationSec,
      status: status ?? this.status,
      bookmarks: bookmarks ?? this.bookmarks,
      createdAt: createdAt,
    );
  }
}
