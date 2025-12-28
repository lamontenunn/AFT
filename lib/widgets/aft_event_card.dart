import 'package:flutter/material.dart';

/// Generic event card with:
/// - leading icon
/// - title
/// - trailing widget (e.g., score ring)
/// - child content area (e.g., input fields)
class AftEventCard extends StatelessWidget {
  const AftEventCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
    this.leading,
    this.compact = false,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  /// Optional custom leading widget (e.g., SVG). If provided, supersedes [icon].
  final Widget? leading;

  /// Compact mode for denser layouts (used on the Home screen).
  /// Reduces padding/margins and uses a smaller title style.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final EdgeInsets margin = compact
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    final EdgeInsets padding = compact
        ? const EdgeInsets.fromLTRB(8, 6, 8, 6)
        : const EdgeInsets.fromLTRB(12, 12, 12, 12);
    final double headerGap = compact ? 4 : 12;
    final textStyle = compact
        ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)
        : theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);

    final leadingWidget = leading ?? Icon(icon, color: cs.onSurfaceVariant);

    return Card(
      margin: margin,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                IconTheme(
                  data: IconThemeData(
                    size: compact ? 18 : 24,
                    color: cs.onSurfaceVariant,
                  ),
                  child: leadingWidget,
                ),
                SizedBox(width: compact ? 6 : 8),
                Expanded(
                  child: Text(
                    title,
                    style: textStyle,
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            SizedBox(height: headerGap),
            // Content area
            child,
          ],
        ),
      ),
    );
  }
}
