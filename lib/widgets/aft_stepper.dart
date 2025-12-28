import 'dart:async';
import 'package:flutter/material.dart';

/// A compact numeric stepper with +/- buttons.
/// - Works with integer values (e.g., seconds for time).
/// - Optional displayFormatter to render the center label (e.g., mm:ss).
/// - Supports press-and-hold auto-repeat with acceleration (mimics 3D Touch style speed-up).
class AftStepper extends StatefulWidget {
  const AftStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min,
    this.max,
    this.step = 1,
    this.displayFormatter,
    this.semanticsLabel,
    this.enableHoldAccelerate = true,
    this.compact = false,
  });

  /// Current value (integer). For time steppers, this can be seconds.
  final int value;

  /// Minimum and maximum allowed values (inclusive). Null means unbounded on that side.
  final int? min;
  final int? max;

  /// Increment/decrement step size (default 1).
  final int step;

  /// Called with the new value when it changes.
  final ValueChanged<int> onChanged;

  /// Optional formatter for the center display.
  /// If provided, the label will render displayFormatter(value) instead of the raw integer.
  final String Function(int value)? displayFormatter;

  /// Optional semantics label for accessibility (e.g., "2-mile run time").
  final String? semanticsLabel;

  /// Enable press-and-hold acceleration (default true).
  final bool enableHoldAccelerate;

  /// Compact rendering for dense layouts.
  final bool compact;

  @override
  State<AftStepper> createState() => _AftStepperState();
}

class _AftStepperState extends State<AftStepper> {
  Timer? _repeatTimer;
  int _repeatCount = 0;

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _repeatCount = 0;
  }

  Duration _intervalForCount(int count) {
    // Accelerate as the hold continues. Tweak as needed.
    if (count < 5) return const Duration(milliseconds: 250);
    if (count < 12) return const Duration(milliseconds: 120);
    if (count < 25) return const Duration(milliseconds: 80);
    return const Duration(milliseconds: 60);
  }

  void _startRepeat(bool increment) {
    // Immediate first step on hold start
    _applyStep(increment);

    if (!widget.enableHoldAccelerate) return;

    _repeatCount = 0;
    // Kick-off a repeating timer with dynamically adjusted interval.
    _repeatTimer = Timer(_intervalForCount(_repeatCount), () {
      // We drive subsequent ticks using periodic scheduling to allow interval changes
      void scheduleNext() {
        if (_repeatTimer == null) return;
        _repeatCount++;
        _applyStep(increment);
        _repeatTimer = Timer(_intervalForCount(_repeatCount), scheduleNext);
      }

      scheduleNext();
    });
  }

  void _applyStep(bool increment) {
    final delta = increment ? widget.step : -widget.step;
    var next = widget.value + delta;
    if (widget.min != null && next < widget.min!) {
      next = widget.min!;
    }
    if (widget.max != null && next > widget.max!) {
      next = widget.max!;
    }
    if (next != widget.value) {
      widget.onChanged(next);
    }
  }

  void _singleTap(bool increment) {
    _applyStep(increment);
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    String centerText =
        widget.displayFormatter?.call(widget.value) ?? '${widget.value}';

    Widget chipButton({
      required IconData icon,
      required bool increment,
      required Color borderColor,
    }) {
      return DecoratedBox(
        decoration: ShapeDecoration(
          shape: StadiumBorder(side: BorderSide(color: borderColor, width: 1)),
        ),
        child: GestureDetector(
          onTap: () => _singleTap(increment),
          onLongPressStart: (_) => _startRepeat(increment),
          onLongPressEnd: (_) => _stopRepeat(),
          onLongPressCancel: _stopRepeat,
          child: ConstrainedBox(
            constraints: BoxConstraints.tightFor(
              width: widget.compact ? 32 : 40,
              height: widget.compact ? 32 : 40,
            ),
            child:
                Icon(icon, size: widget.compact ? 15 : 18, color: cs.onSurface),
          ),
        ),
      );
    }

    return Semantics(
      label: widget.semanticsLabel ?? 'Adjust value',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          chipButton(
            icon: Icons.remove,
            increment: false,
            borderColor: cs.outline,
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.compact ? 4 : 6),
            child: SizedBox(
              width: widget.compact ? 44 : 56, // widened to fit "mm:ss"
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  centerText,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ),
          ),
          chipButton(
            icon: Icons.add,
            increment: true,
            borderColor: cs.primary,
          ),
        ],
      ),
    );
  }
}
