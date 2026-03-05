import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class AmplitudeVisualizer extends StatefulWidget {
  final Stream<double> amplitudeStream;
  final bool isRecording;

  const AmplitudeVisualizer({
    super.key,
    required this.amplitudeStream,
    required this.isRecording,
  });

  @override
  State<AmplitudeVisualizer> createState() => _AmplitudeVisualizerState();
}

class _AmplitudeVisualizerState extends State<AmplitudeVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final List<double> _amplitudes = List.filled(40, 0.0);
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // ~60fps
    )..repeat();

    widget.amplitudeStream.listen((amplitude) {
      if (mounted && widget.isRecording) {
        setState(() {
          _amplitudes[_currentIndex] = amplitude;
          _currentIndex = (_currentIndex + 1) % _amplitudes.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(double.infinity, 80),
          painter: _AmplitudePainter(
            amplitudes: _amplitudes,
            currentIndex: _currentIndex,
            isRecording: widget.isRecording,
          ),
        );
      },
    );
  }
}

class _AmplitudePainter extends CustomPainter {
  final List<double> amplitudes;
  final int currentIndex;
  final bool isRecording;

  _AmplitudePainter({
    required this.amplitudes,
    required this.currentIndex,
    required this.isRecording,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / amplitudes.length;
    final maxBarHeight = size.height * 0.8;
    final centerY = size.height / 2;

    for (int i = 0; i < amplitudes.length; i++) {
      final index = (currentIndex - amplitudes.length + i + amplitudes.length) %
          amplitudes.length;
      final amplitude = amplitudes[index];

      final barHeight = max(4.0, amplitude * maxBarHeight);
      final x = i * barWidth + barWidth / 2;

      final opacity = isRecording ? (0.3 + 0.7 * (i / amplitudes.length)) : 0.3;

      final paint = Paint()
        ..color = isRecording
            ? AppTheme.recordingRed.withValues(alpha: opacity)
            : AppTheme.textTertiary.withValues(alpha: 0.3)
        ..strokeWidth = barWidth * 0.6
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AmplitudePainter oldDelegate) => true;
}
