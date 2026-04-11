import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_theme.dart';
import '../../core/l10n/app_localizations.dart';
import '../../data/models/note.dart';
import '../../providers/providers.dart';

class ProcessingScreen extends ConsumerStatefulWidget {
  final String noteId;

  const ProcessingScreen({super.key, required this.noteId});

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  StreamSubscription? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _subscribeToUpdates();
  }

  void _subscribeToUpdates() {
    final dbService = ref.read(databaseServiceProvider);
    dbService.subscribeToNote(
      widget.noteId,
      onUpdate: (payload) {
        final status =
            NoteStatus.fromString(payload['status'] as String? ?? '');
        if (status == NoteStatus.done) {
          _navigateToDetail();
        } else if (status == NoteStatus.error) {
          setState(() {});
        }
        // Refresh note detail
        ref.invalidate(noteDetailProvider(widget.noteId));
      },
    );
    _realtimeSub = null; // Channel handles its own lifecycle
  }

  void _navigateToDetail() {
    if (mounted) {
      context.go('/notes/${widget.noteId}');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _realtimeSub?.cancel();
    final dbService = ref.read(databaseServiceProvider);
    dbService.unsubscribeFromNote(widget.noteId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final noteAsync = ref.watch(noteDetailProvider(widget.noteId));

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.watch(localeProvider).processingTitle),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: noteAsync.when(
            data: (note) => _buildContent(context, note),
            loading: () => _buildLoading(context),
            error: (e, _) => _buildError(context, e.toString()),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Note? note) {
    if (note == null) return _buildError(context, ref.read(localeProvider).noteNotFound);

    final status = note.status;
    if (status == NoteStatus.done) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToDetail();
      });
      return _buildLoading(context);
    }

    if (status == NoteStatus.error) {
      return _buildError(context, ref.read(localeProvider).processingError);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated processing icon
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final scale = 1.0 + _pulseController.value * 0.1;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryLight,
                ),
                child: Icon(
                  _statusIcon(status),
                  size: 48,
                  color: AppTheme.primaryColor,
                ),
              ),
            );
          },
        ),
        const Gap(32),

        Text(
          _statusTitle(status),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const Gap(12),

        Text(
          _statusDescription(status),
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const Gap(32),

        // Progress steps
        _ProgressSteps(currentStatus: status, l10n: ref.read(localeProvider)),

        const Gap(48),

        if (note.durationSec != null)
          Text(
            ref.read(localeProvider).duration(note.durationFormatted),
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: AppTheme.primaryColor),
        const Gap(16),
        Text(ref.read(localeProvider).loading),
      ],
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline_rounded, size: 64, color: AppTheme.errorColor),
        const Gap(16),
        Text(message, style: Theme.of(context).textTheme.bodyLarge),
        const Gap(24),
        ElevatedButton(
          onPressed: () => context.go('/'),
          child: Text(ref.read(localeProvider).goHome),
        ),
      ],
    );
  }

  IconData _statusIcon(NoteStatus status) {
    switch (status) {
      case NoteStatus.uploading:
        return Icons.cloud_upload_rounded;
      case NoteStatus.transcribing:
        return Icons.hearing_rounded;
      case NoteStatus.summarizing:
        return Icons.auto_awesome_rounded;
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  String _statusTitle(NoteStatus status) {
    final l10n = ref.read(localeProvider);
    switch (status) {
      case NoteStatus.uploading:
        return l10n.uploadingAudio;
      case NoteStatus.transcribing:
        return l10n.transcribing;
      case NoteStatus.summarizing:
        return l10n.summarizingAI;
      default:
        return l10n.processingTitle;
    }
  }

  String _statusDescription(NoteStatus status) {
    final l10n = ref.read(localeProvider);
    switch (status) {
      case NoteStatus.uploading:
        return l10n.uploadingDesc;
      case NoteStatus.transcribing:
        return l10n.transcribingDesc;
      case NoteStatus.summarizing:
        return l10n.summarizingDesc;
      default:
        return l10n.pleaseWait;
    }
  }
}

class _ProgressSteps extends StatelessWidget {
  final NoteStatus currentStatus;
  final AppLocalizations l10n;

  const _ProgressSteps({required this.currentStatus, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final steps = [
      _Step(l10n.stepUpload, NoteStatus.uploading),
      _Step(l10n.stepTranscribe, NoteStatus.transcribing),
      _Step(l10n.stepSummarize, NoteStatus.summarizing),
    ];

    final currentIndex = steps.indexWhere((s) => s.status == currentStatus);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Container(
              width: 32,
              height: 2,
              color: i <= currentIndex
                  ? AppTheme.primaryColor
                  : AppTheme.dividerColor,
            ),
          _StepDot(
            label: steps[i].label,
            isActive: i == currentIndex,
            isCompleted: i < currentIndex,
          ),
        ],
      ],
    );
  }
}

class _Step {
  final String label;
  final NoteStatus status;
  const _Step(this.label, this.status);
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isCompleted;

  const _StepDot({
    required this.label,
    required this.isActive,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive || isCompleted
                ? AppTheme.primaryColor
                : AppTheme.dividerColor,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : isActive
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : null,
          ),
        ),
        const Gap(6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isActive || isCompleted
                    ? AppTheme.primaryColor
                    : AppTheme.textTertiary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
        ),
      ],
    );
  }
}
