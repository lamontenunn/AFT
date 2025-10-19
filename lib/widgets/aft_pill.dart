import 'package:flutter/material.dart';

/// A compact rounded "pill" container suitable for inline inputs or tags.
/// Provides padding, outline, and proper contrast for dark theme.
/// Optionally tappable (InkWell) with tooltip.
class AftPill extends StatelessWidget {
  const AftPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.backgroundColor,
    this.outlineColor,
    this.onTap,
    this.tooltip,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? outlineColor;

  /// Optional tap handler. When provided, the pill is wrapped with an InkWell.
  final VoidCallback? onTap;

  /// Optional tooltip when [onTap] is provided.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final base = Container(
      padding: padding,
      decoration: ShapeDecoration(
        color: backgroundColor ?? colorScheme.surfaceContainerHighest.withOpacity(0.15),
        shape: StadiumBorder(
          side: BorderSide(color: outlineColor ?? colorScheme.outline, width: 1),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
          height: 1.1,
        ),
        child: child,
      ),
    );

    Widget pill = base;
    if (onTap != null) {
      pill = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: base,
        ),
      );
      if (tooltip != null) {
        pill = Tooltip(message: tooltip!, child: pill);
      }
    }

    return pill;
  }
}
