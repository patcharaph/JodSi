import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../models/models.dart';

class DatabaseService {
  final SupabaseClient _client = SupabaseConfig.client;

  // ─── Notes ───────────────────────────────────────────

  Future<Note> createNote({
    required String userId,
    String? title,
  }) async {
    final response = await _client
        .from('notes')
        .insert({
          'user_id': userId,
          'title': title,
          'status': NoteStatus.recording.name,
        })
        .select()
        .single();

    return Note.fromJson(response);
  }

  Future<Note> updateNote(String noteId, Map<String, dynamic> data) async {
    final response = await _client
        .from('notes')
        .update(data)
        .eq('id', noteId)
        .select()
        .single();

    return Note.fromJson(response);
  }

  Future<List<Note>> getNotes(String userId) async {
    final response = await _client
        .from('notes')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Note.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Note?> getNote(String noteId) async {
    final response = await _client
        .from('notes')
        .select()
        .eq('id', noteId)
        .maybeSingle();

    if (response == null) return null;
    return Note.fromJson(response);
  }

  Future<void> deleteNote(String noteId) async {
    await _client.from('notes').delete().eq('id', noteId);
  }

  // ─── Transcripts ────────────────────────────────────

  Future<Transcript?> getTranscript(String noteId) async {
    final response = await _client
        .from('transcripts')
        .select()
        .eq('note_id', noteId)
        .maybeSingle();

    if (response == null) return null;
    return Transcript.fromJson(response);
  }

  // ─── Summaries ──────────────────────────────────────

  Future<Summary?> getSummary(String noteId) async {
    final response = await _client
        .from('summaries')
        .select()
        .eq('note_id', noteId)
        .maybeSingle();

    if (response == null) return null;
    return Summary.fromJson(response);
  }

  // Emits the current summary, then re-emits when it's inserted (streaming flow).
  Stream<Summary?> watchSummary(String noteId) async* {
    yield await getSummary(noteId);

    final controller = StreamController<Summary?>();
    final channel = _client
        .channel('watch-summary-$noteId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'summaries',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'note_id',
            value: noteId,
          ),
          callback: (payload) {
            try {
              controller.add(Summary.fromJson(payload.newRecord));
            } catch (_) {}
          },
        )
        .subscribe();

    try {
      await for (final summary in controller.stream) {
        yield summary;
      }
    } finally {
      await _client.removeChannel(channel);
      await controller.close();
    }
  }

  // ─── Realtime ───────────────────────────────────────

  RealtimeChannel subscribeToNote(
    String noteId, {
    required void Function(Map<String, dynamic> payload) onUpdate,
  }) {
    return _client
        .channel('note-$noteId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: noteId,
          ),
          callback: (payload) {
            onUpdate(payload.newRecord);
          },
        )
        .subscribe();
  }

  void unsubscribeFromNote(String noteId) {
    _client.removeChannel(_client.channel('note-$noteId'));
  }
}
