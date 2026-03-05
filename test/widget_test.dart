import 'package:flutter_test/flutter_test.dart';

import 'package:jodsi/data/models/models.dart';

void main() {
  group('Note model', () {
    test('durationFormatted returns correct format', () {
      final note = Note(
        id: 'test-id',
        userId: 'user-id',
        durationSec: 125,
        createdAt: DateTime.now(),
      );
      expect(note.durationFormatted, '02:05');
    });

    test('displayTitle returns fallback when title is null', () {
      final note = Note(
        id: 'test-id',
        userId: 'user-id',
        createdAt: DateTime.now(),
      );
      expect(note.displayTitle, 'โน้ตไม่มีชื่อ');
    });

    test('isProcessing returns true for uploading/transcribing/summarizing', () {
      for (final status in [
        NoteStatus.uploading,
        NoteStatus.transcribing,
        NoteStatus.summarizing,
      ]) {
        final note = Note(
          id: 'test-id',
          userId: 'user-id',
          status: status,
          createdAt: DateTime.now(),
        );
        expect(note.isProcessing, true);
      }
    });
  });

  group('Summary model', () {
    test('toClipboardText formats correctly', () {
      const summary = Summary(
        id: 'sum-id',
        noteId: 'note-id',
        keyTakeaways: ['Point 1', 'Point 2'],
        detail: 'Some detail text',
        actionItems: ['Do thing 1'],
      );
      final text = summary.toClipboardText();
      expect(text, contains('Key Takeaways'));
      expect(text, contains('Point 1'));
      expect(text, contains('Detail'));
      expect(text, contains('Action Items'));
    });
  });
}
