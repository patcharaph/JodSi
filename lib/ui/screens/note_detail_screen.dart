import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_theme.dart';
import '../../core/l10n/app_localizations.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';

class NoteDetailScreen extends ConsumerStatefulWidget {
  final String noteId;

  const NoteDetailScreen({super.key, required this.noteId});

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final noteAsync = ref.watch(noteDetailProvider(widget.noteId));
    final summaryAsync = ref.watch(summaryProvider(widget.noteId));
    final transcriptAsync = ref.watch(transcriptProvider(widget.noteId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/notes'),
        ),
        title: noteAsync.when(
          data: (note) => Text(note?.displayTitle ?? ref.read(localeProvider).note),
          loading: () => Text(ref.read(localeProvider).note),
          error: (_, __) => Text(ref.read(localeProvider).note),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: ref.read(localeProvider).copy,
            onPressed: () => _copyToClipboard(context, summaryAsync),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: ref.read(localeProvider).delete,
            onPressed: () => _deleteNote(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textTertiary,
          tabs: [
            Tab(text: ref.read(localeProvider).tabSummary),
            Tab(text: ref.read(localeProvider).tabTranscript),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Summary
          _SummaryTab(summaryAsync: summaryAsync, l10n: ref.read(localeProvider)),

          // Tab 2: Transcript
          _TranscriptTab(
            transcriptAsync: transcriptAsync,
            noteAsync: noteAsync,
            l10n: ref.read(localeProvider),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(
    BuildContext context,
    AsyncValue<Summary?> summaryAsync,
  ) {
    final summary = summaryAsync.valueOrNull;
    if (summary == null) return;

    Clipboard.setData(ClipboardData(text: summary.toClipboardText()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ref.read(localeProvider).copiedSummary),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteNote(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ref.read(localeProvider).deleteNoteTitle),
        content: Text(ref.read(localeProvider).deleteNoteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(ref.read(localeProvider).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: Text(ref.read(localeProvider).delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(notesListProvider.notifier).deleteNote(widget.noteId);
      if (mounted) context.go('/notes');
    }
  }
}

class _SummaryTab extends StatelessWidget {
  final AsyncValue<Summary?> summaryAsync;
  final AppLocalizations l10n;

  const _SummaryTab({required this.summaryAsync, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return summaryAsync.when(
      data: (summary) {
        if (summary == null) {
          return Center(child: Text(l10n.noSummaryYet));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Key Takeaways
              if (summary.keyTakeaways.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.lightbulb_rounded,
                  title: 'Key Takeaways',
                  color: AppTheme.primaryColor,
                ),
                const Gap(12),
                ...summary.keyTakeaways.map((item) => _BulletItem(text: item)),
                const Gap(24),
              ],

              // Detail
              if (summary.detail != null && summary.detail!.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.notes_rounded,
                  title: l10n.sectionDetail,
                  color: Colors.blue,
                ),
                const Gap(12),
                Text(
                  summary.detail!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.7,
                      ),
                ),
                const Gap(24),
              ],

              // Action Items
              if (summary.actionItems.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Action Items',
                  color: AppTheme.successColor,
                ),
                const Gap(12),
                ...summary.actionItems.map(
                  (item) => _CheckItem(text: item),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      ),
      error: (e, _) => Center(child: Text(l10n.errorWith(e.toString()))),
    );
  }
}

class _TranscriptTab extends StatelessWidget {
  final AsyncValue<Transcript?> transcriptAsync;
  final AsyncValue<Note?> noteAsync;
  final AppLocalizations l10n;

  const _TranscriptTab({
    required this.transcriptAsync,
    required this.noteAsync,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final bookmarks = noteAsync.valueOrNull?.bookmarks ?? [];

    return transcriptAsync.when(
      data: (transcript) {
        if (transcript == null) {
          return Center(child: Text(l10n.noTranscriptYet));
        }

        if (transcript.segments.isEmpty && transcript.fullText != null) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Text(
              transcript.fullText!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.7,
                  ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: transcript.segments.length,
          separatorBuilder: (_, __) => const Gap(8),
          itemBuilder: (context, index) {
            final segment = transcript.segments[index];
            final hasBookmark = bookmarks.any(
              (b) =>
                  b.timestampSec >= segment.start &&
                  b.timestampSec <= segment.end,
            );

            return _TranscriptSegmentTile(
              segment: segment,
              hasBookmark: hasBookmark,
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      ),
      error: (e, _) => Center(child: Text(l10n.errorWith(e.toString()))),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const Gap(8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryColor,
            ),
          ),
          const Gap(12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String text;
  const _CheckItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_box_outline_blank_rounded,
            size: 20,
            color: AppTheme.successColor,
          ),
          const Gap(12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TranscriptSegmentTile extends StatelessWidget {
  final TranscriptSegment segment;
  final bool hasBookmark;

  const _TranscriptSegmentTile({
    required this.segment,
    required this.hasBookmark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasBookmark
            ? AppTheme.primaryLight.withValues(alpha: 0.5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: hasBookmark
            ? Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              segment.startFormatted,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFeatures: [const FontFeature.tabularFigures()],
                    fontSize: 11,
                  ),
            ),
          ),
          if (hasBookmark) ...[
            const Gap(4),
            const Icon(Icons.bookmark_rounded,
                size: 16, color: AppTheme.primaryColor),
          ],
          const Gap(10),
          Expanded(
            child: Text(
              segment.text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
