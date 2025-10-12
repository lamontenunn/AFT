import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aft_firebase_app/theme/army_colors.dart';

/// Animated circular score indicator with Army gold arc and a numeric value (or '—').
/// - [score] null displays placeholder '—' and 0 progress
/// - [max] used to compute progress (defaults to 100)
/// - [size] overall square size of ring
/// - [stroke] thickness of ring
class AftScoreRing extends StatelessWidget {
  const AftScoreRing({
    super.key,
    required this.score,
    this.max = 100,
    this.size = 56,
    this.stroke = 6,
    this.duration = const Duration(milliseconds: 700),
  });

  final int? score;
  final int max;
  final double size;
  final double stroke;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final value = (score ?? 0).clamp(0, max);
    final target = max == 0 ? 0.0 : value / max;

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: target),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, t, _) {
          return CustomPaint(
            painter: _RingPainter(
              progress: t,
              stroke: stroke,
              trackColor: cs.outline.withOpacity(0.35),
              progressColor: ArmyColors.gold,
            ),
            child: Center(
              child: Text(
                score == null ? '—' : '$value',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.stroke,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final double stroke;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2 - stroke / 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    final progPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = progressColor;

    // Track (full circle)
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc: start at -90deg (top)
    final startAngle = -math.pi / 2;
    final sweep = (math.pi * 2) * progress.clamp(0.0, 1.0);
    final rectCircle = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rectCircle, startAngle, sweep, false, progPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        stroke != oldDelegate.stroke ||
        trackColor != oldDelegate.trackColor ||
        progressColor != oldDelegate.progressColor;
  }
}
