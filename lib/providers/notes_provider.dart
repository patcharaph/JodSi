import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/models.dart';
import 'service_providers.dart';

final notesListProvider =
    AsyncNotifierProvider<NotesListNotifier, List<Note>>(
  NotesListNotifier.new,
);

class NotesListNotifier extends AsyncNotifier<List<Note>> {
  @override
  Future<List<Note>> build() async {
    final authService = ref.watch(authServiceProvider);
    final dbService = ref.watch(databaseServiceProvider);
    final userId = authService.currentUserId;
    if (userId == null) return [];
    return dbService.getNotes(userId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  Future<Note> createNote({String? title}) async {
    final authService = ref.read(authServiceProvider);
    final dbService = ref.read(databaseServiceProvider);
    final userId = authService.currentUserId!;

    final note = await dbService.createNote(userId: userId, title: title);

    // Prepend to current list
    final currentNotes = state.valueOrNull ?? [];
    state = AsyncData([note, ...currentNotes]);

    return note;
  }

  void updateNoteInList(Note updatedNote) {
    final currentNotes = state.valueOrNull ?? [];
    final index = currentNotes.indexWhere((n) => n.id == updatedNote.id);
    if (index >= 0) {
      final newList = [...currentNotes];
      newList[index] = updatedNote;
      state = AsyncData(newList);
    }
  }

  Future<void> deleteNote(String noteId) async {
    final dbService = ref.read(databaseServiceProvider);
    await dbService.deleteNote(noteId);
    final currentNotes = state.valueOrNull ?? [];
    state = AsyncData(currentNotes.where((n) => n.id != noteId).toList());
  }
}

final noteDetailProvider =
    FutureProvider.family<Note?, String>((ref, noteId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getNote(noteId);
});

final transcriptProvider =
    FutureProvider.family<Transcript?, String>((ref, noteId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getTranscript(noteId);
});

final summaryProvider =
    FutureProvider.family<Summary?, String>((ref, noteId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getSummary(noteId);
});
