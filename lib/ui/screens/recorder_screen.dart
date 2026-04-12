import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../widgets/amplitude_visualizer.dart';
import '../widgets/link_account_sheet.dart';

class RecorderScreen extends ConsumerStatefulWidget {
  const RecorderScreen({super.key});

  @override
  ConsumerState<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends ConsumerState<RecorderScreen> {
  static const double _lowAmplitudeThreshold = 0.08;
  static const int _lowAmplitudeConsecutiveTicks = 6;

  StreamSubscription<double>? _amplitudeSub;
  double _smoothedAmplitude = 0.0;
  int _lowAmplitudeTicks = 0;
  bool _isLowInput = false;

  @override
  void initState() {
    super.initState();
    _ensureAuth();
    _subscribeAmplitude();

    // Register auto-stop callback for recording time limit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recordingProvider.notifier).onAutoStop = () {
        _handleRecordTap(context);
      };
    });
  }

  void _subscribeAmplitude() {
    final recorder = ref.read(audioRecordingServiceProvider);
    _amplitudeSub = recorder.amplitudeStream.listen((amplitude) {
      if (!mounted) return;

      final isRecording =
          ref.read(recordingProvider).state == RecordingState.recording;

      if (!isRecording) {
        if (_isLowInput || _smoothedAmplitude > 0 || _lowAmplitudeTicks > 0) {
          setState(() {
            _isLowInput = false;
            _smoothedAmplitude = 0.0;
            _lowAmplitudeTicks = 0;
          });
        }
        return;
      }

      _smoothedAmplitude = (_smoothedAmplitude * 0.7) + (amplitude * 0.3);
      if (_smoothedAmplitude < _lowAmplitudeThreshold) {
        _lowAmplitudeTicks++;
      } else {
        _lowAmplitudeTicks = 0;
      }

      final nextLowInput = _lowAmplitudeTicks >= _lowAmplitudeConsecutiveTicks;
      if (nextLowInput != _isLowInput) {
        setState(() => _isLowInput = nextLowInput);
      }
    });
  }

  @override
  void dispose() {
    _amplitudeSub?.cancel();
    super.dispose();
  }

  Future<void> _ensureAuth() async {
    final authService = ref.read(authServiceProvider);
    await authService.ensureAuthenticated();
    if (mounted) {
      await authService.ensureProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final recordingStatus = ref.watch(recordingProvider);
    final recorder = ref.read(audioRecordingServiceProvider);
    final isRecording = recordingStatus.state == RecordingState.recording;
    final isUploading = recordingStatus.state == RecordingState.uploading;
    final waveformColor = isRecording
        ? (_isLowInput ? AppTheme.errorColor : Colors.green)
        : AppTheme.recordingRed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('JodSi'),
        leading: IconButton(
          icon: const Icon(Icons.history_rounded),
          onPressed: () => context.push('/notes'),
          tooltip: ref.watch(localeProvider).notesHistory,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => context.push('/settings'),
            tooltip: ref.watch(localeProvider).settings,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Amplitude visualizer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: AmplitudeVisualizer(
                amplitudeStream: recorder.amplitudeStream,
                isRecording: isRecording,
                activeColor: waveformColor,
              ),
            ),
            const Gap(32),

            // Timer display
            Text(
              recordingStatus.elapsedFormatted,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontSize: 56,
                    fontWeight: FontWeight.w300,
                    color: isRecording
                        ? AppTheme.recordingRed
                        : AppTheme.textPrimary,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
            ),
            const Gap(8),

            // Status text
            Text(
              _statusText(recordingStatus),
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            if (isRecording && _isLowInput) ...[
              const Gap(8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: AppTheme.errorColor,
                  ),
                  const Gap(6),
                  Text(
                    'เสียงเบาเกินไป ลองวางมือถือใกล้ขึ้น',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.errorColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],

            // Bookmarks count
            if (recordingStatus.bookmarks.isNotEmpty) ...[
              const Gap(8),
              Text(
                ref.watch(localeProvider).bookmarksCount(recordingStatus.bookmarks.length),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.primaryColor,
                    ),
              ),
            ],

            const Spacer(flex: 2),

            // Bookmark button (visible during recording)
            if (isRecording)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextButton.icon(
                  onPressed: () =>
                      ref.read(recordingProvider.notifier).addBookmark(),
                  icon: const Icon(Icons.bookmark_add_rounded, size: 20),
                  label: Text(ref.watch(localeProvider).addBookmark),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),
              ),

            // Record button
            _RecordButton(
              isRecording: isRecording,
              isLoading: isUploading,
              onTap: () => _handleRecordTap(context),
            ),

            const Gap(16),

            // Error message
            if (recordingStatus.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  recordingStatus.errorMessage!,
                  style: TextStyle(color: AppTheme.errorColor, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),

            const Spacer(),
          ],
        ),
      ),
    );
  }

  String _statusText(RecordingStatus status) {
    final l10n = ref.read(localeProvider);
    switch (status.state) {
      case RecordingState.idle:
        return l10n.tapToRecord;
      case RecordingState.recording:
        return l10n.recording;
      case RecordingState.uploading:
        return l10n.uploading;
      case RecordingState.processing:
        return l10n.processing;
    }
  }

  Future<void> _handleRecordTap(BuildContext context) async {
    final notifier = ref.read(recordingProvider.notifier);
    final status = ref.read(recordingProvider);

    if (status.state == RecordingState.idle) {
      setState(() {
        _isLowInput = false;
        _smoothedAmplitude = 0.0;
        _lowAmplitudeTicks = 0;
      });
      await notifier.startRecording();
    } else if (status.state == RecordingState.recording) {
      final noteId = await notifier.stopRecording();

      // Check soft prompt before resetting state
      final shouldPrompt = await notifier.shouldShowSoftPrompt();
      final isAnon = ref.read(isAnonymousProvider);

      notifier.reset();

      if (noteId != null && mounted) {
        await context.push('/processing/$noteId');

        // Show soft prompt only after returning from processing screen
        if (shouldPrompt && isAnon && mounted) {
          LinkAccountSheet.show(context);
        }
      }
    }
  }
}

class _RecordButton extends StatelessWidget {
  final bool isRecording;
  final bool isLoading;
  final VoidCallback onTap;

  const _RecordButton({
    required this.isRecording,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isLoading
              ? AppTheme.textTertiary
              : isRecording
                  ? AppTheme.recordingRed
                  : AppTheme.primaryColor,
          boxShadow: [
            BoxShadow(
              color: (isRecording ? AppTheme.recordingRed : AppTheme.primaryColor)
                  .withValues(alpha: 0.3),
              blurRadius: isRecording ? 24 : 12,
              spreadRadius: isRecording ? 4 : 0,
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isRecording ? 24 : 28,
                  height: isRecording ? 24 : 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(isRecording ? 4 : 14),
                  ),
                ),
        ),
      ),
    );
  }
}
