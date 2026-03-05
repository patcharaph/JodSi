class Summary {
  final String id;
  final String noteId;
  final List<String> keyTakeaways;
  final String? detail;
  final List<String> actionItems;

  const Summary({
    required this.id,
    required this.noteId,
    this.keyTakeaways = const [],
    this.detail,
    this.actionItems = const [],
  });

  factory Summary.fromJson(Map<String, dynamic> json) {
    return Summary(
      id: json['id'] as String,
      noteId: json['note_id'] as String,
      keyTakeaways: (json['key_takeaways'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      detail: json['detail'] as String?,
      actionItems: (json['action_items'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'note_id': noteId,
        'key_takeaways': keyTakeaways,
        'detail': detail,
        'action_items': actionItems,
      };

  String toClipboardText() {
    final buffer = StringBuffer();

    if (keyTakeaways.isNotEmpty) {
      buffer.writeln('📌 Key Takeaways');
      for (final item in keyTakeaways) {
        buffer.writeln('• $item');
      }
      buffer.writeln();
    }

    if (detail != null && detail!.isNotEmpty) {
      buffer.writeln('📝 Detail');
      buffer.writeln(detail);
      buffer.writeln();
    }

    if (actionItems.isNotEmpty) {
      buffer.writeln('✅ Action Items');
      for (final item in actionItems) {
        buffer.writeln('☐ $item');
      }
    }

    return buffer.toString().trimRight();
  }
}
