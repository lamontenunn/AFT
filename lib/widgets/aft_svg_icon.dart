import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Uniform SVG icon wrapper to normalize visual size regardless of source viewBox.
/// - Renders inside a fixed square [size]
/// - Applies [padding] to achieve consistent perceived ink size
/// - Uses BoxFit.contain so various aspect ratios scale uniformly
class AftSvgIcon extends StatelessWidget {
  const AftSvgIcon(
    this.asset, {
    super.key,
    this.size = 24,
    this.padding = const EdgeInsets.all(2),
    this.colorFilter,
    this.semanticLabel,
  });

  final String asset;
  final double size;
  final EdgeInsets padding;
  final ColorFilter? colorFilter;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Padding(
        padding: padding,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SvgPicture.asset(
            asset,
            colorFilter: colorFilter,
            semanticsLabel: semanticLabel,
          ),
        ),
      ),
    );
  }
}
