import 'package:flutter/material.dart';

/// A compact numeric stepper with +/- buttons.
/// Intrinsic width; buttons are tightly constrained to 40x40 for predictable layout.
class AftStepper extends StatelessWidget {
  const AftStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min,
    this.max,
    this.step = 1,
  });

  final int value;
  final int? min;
  final int? max;
  final int step;
  final ValueChanged<int> onChanged;

  void _inc() {
    final next = value + step;
    if (max != null && next > max!) return;
    onChanged(next);
  }

  void _dec() {
    final next = value - step;
    if (min != null && next < min!) return;
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget chipButton({
      required IconData icon,
      required VoidCallback onPressed,
      required Color borderColor,
    }) {
      return DecoratedBox(
        decoration: ShapeDecoration(
          shape: StadiumBorder(side: BorderSide(color: borderColor, width: 1)),
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 18, color: cs.onSurface),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return Semantics(
      label: 'Adjust value',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          chipButton(
            icon: Icons.remove,
            onPressed: _dec,
            borderColor: cs.outline,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SizedBox(
              width: 36,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$value',
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
            onPressed: _inc,
            borderColor: cs.primary,
          ),
        ],
      ),
    );
  }
}
