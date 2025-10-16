import 'package:flutter/material.dart';
import 'package:aft_firebase_app/theme/army_colors.dart';

/// Army-themed choice chip with rounded (stadium) shape and strong contrast
/// in dark mode. Uses Army gold when selected.
class AftChoiceChip extends StatelessWidget {
  const AftChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.compact = true,
    this.leading,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final bool compact;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final bg = selected
        ? ArmyColors.gold.withOpacity(0.18)
        : cs.surfaceContainerHighest.withOpacity(0.10);

    final borderColor = selected ? ArmyColors.gold : cs.outline;
    final textColor = selected ? ArmyColors.black : cs.onSurface;

    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 8);

    return Material(
      color: bg,
      shape: StadiumBorder(side: BorderSide(color: borderColor, width: 1)),
      child: InkWell(
        onTap: () => onSelected(!selected),
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                IconTheme(
                  data: IconThemeData(
                    size: 16,
                    color: selected ? ArmyColors.black : cs.onSurfaceVariant,
                  ),
                  child: leading!,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
