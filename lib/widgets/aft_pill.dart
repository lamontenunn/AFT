import 'package:flutter/material.dart';

/// A compact rounded "pill" container suitable for inline inputs or tags.
/// Provides padding, outline, and proper contrast for dark theme.
class AftPill extends StatelessWidget {
  const AftPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.backgroundColor,
    this.outlineColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? outlineColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: padding,
      decoration: ShapeDecoration(
        color: backgroundColor ?? colorScheme.surfaceVariant.withOpacity(0.15),
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
  }
}
