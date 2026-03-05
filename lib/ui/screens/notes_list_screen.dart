import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/app_theme.dart';
import '../../core/l10n/app_localizations.dart';
import '../../data/models/note.dart';
import '../../providers/providers.dart';

class NotesListScreen extends ConsumerWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesListProvider);
    final l10n = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.allNotes),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
      ),
      body: notesAsync.when(
        data: (notes) {
          if (notes.isEmpty) {
            return _EmptyState(l10n: l10n);
          }
          return RefreshIndicator(
            color: AppTheme.primaryColor,
            onRefresh: () =>
                ref.read(notesListProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notes.length,
              separatorBuilder: (_, __) => const Gap(8),
              itemBuilder: (context, index) {
                final note = notes[index];
                return _NoteCard(note: note, l10n: l10n);
              },
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppTheme.errorColor),
              const Gap(16),
              Text(l10n.errorWith(e.toString())),
              const Gap(16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(notesListProvider.notifier).refresh(),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.mic_rounded),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppLocalizations l10n;
  const _EmptyState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.note_add_rounded,
              size: 80,
              color: AppTheme.textTertiary.withValues(alpha: 0.5),
            ),
            const Gap(24),
            Text(
              l10n.noNotesYet,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Gap(8),
            Text(
              l10n.startRecordingPrompt,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const Gap(32),
            ElevatedButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.mic_rounded),
              label: Text(l10n.recordVoice),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final AppLocalizations l10n;

  const _NoteCard({required this.note, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () {
          if (note.isProcessing) {
            context.push('/processing/${note.id}');
          } else if (note.status == NoteStatus.done) {
            context.push('/notes/${note.id}');
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Status icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _statusColor.withValues(alpha: 0.1),
                ),
                child: Icon(
                  _statusIcon,
                  size: 22,
                  color: _statusColor,
                ),
              ),
              const Gap(14),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.displayTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(4),
                    Row(
                      children: [
                        Text(
                          note.durationFormatted,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Gap(8),
                        Text(
                          '·',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Gap(8),
                        Text(
                          timeago.format(note.createdAt, locale: 'en_short'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (note.isProcessing) ...[
                          const Gap(8),
                          _StatusBadge(status: note.status, l10n: l10n),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow
              if (note.status == NoteStatus.done)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color get _statusColor {
    switch (note.status) {
      case NoteStatus.done:
        return AppTheme.successColor;
      case NoteStatus.error:
        return AppTheme.errorColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData get _statusIcon {
    switch (note.status) {
      case NoteStatus.done:
        return Icons.description_rounded;
      case NoteStatus.error:
        return Icons.error_outline_rounded;
      case NoteStatus.recording:
        return Icons.mic_rounded;
      default:
        return Icons.hourglass_top_rounded;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final NoteStatus status;
  final AppLocalizations l10n;
  const _StatusBadge({required this.status, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _label,
        style: const TextStyle(
          fontSize: 11,
          color: AppTheme.primaryDark,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String get _label {
    switch (status) {
      case NoteStatus.uploading:
        return l10n.badgeUploading;
      case NoteStatus.transcribing:
        return l10n.badgeTranscribing;
      case NoteStatus.summarizing:
        return l10n.badgeSummarizing;
      default:
        return l10n.badgeProcessing;
    }
  }
}
