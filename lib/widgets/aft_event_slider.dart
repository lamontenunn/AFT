import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aft_firebase_app/features/aft/logic/slider_config.dart';

class AftIntSlider extends StatelessWidget {
  const AftIntSlider({
    super.key,
    required this.label,
    required this.value,
    required this.config,
    required this.onChanged,
    this.suffix,
  });

  final String label;
  final int value;
  final SliderConfig config;
  final ValueChanged<int> onChanged;
  final String? suffix;

  int _snap(double v) {
    final step = config.step;
    final snapped = (v / step).round() * step;
    return snapped.clamp(config.min, config.max).toInt();
  }

  @override
  Widget build(BuildContext context) {
    assert(config.domain == SliderDomainType.integer);
    final theme = Theme.of(context);
    final min = config.min;
    final max = config.max;
    final divisions = config.divisions != null && config.divisions! > 0
        ? config.divisions
        : ((max - min) ~/ config.step).clamp(1, 1000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with current value
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            Semantics(
              label: label,
              value: suffix == null ? '$value' : '$value $suffix',
              child: Text(
                suffix == null ? '$value' : '$value $suffix',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            showValueIndicator: ShowValueIndicator.always,
          ),
          child: Slider(
            value: value.clamp(min.toInt(), max.toInt()).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            label: suffix == null ? '$value' : '$value $suffix',
            onChanged: (v) => onChanged(_snap(v)),
          ),
        ),
        // Min/Max labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(suffix == null ? '${min.toInt()}' : '${min.toInt()} $suffix',
                style: theme.textTheme.labelSmall),
            Text(suffix == null ? '${max.toInt()}' : '${max.toInt()} $suffix',
                style: theme.textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}

class AftTimeSlider extends StatelessWidget {
  const AftTimeSlider({
    super.key,
    required this.label,
    required this.seconds,
    required this.config,
    required this.onChanged,
  });

  final String label;
  final int seconds; // current value in seconds
  final SliderConfig config;
  final ValueChanged<int> onChanged;

  int _snap(double v) {
    final step = config.step;
    final snapped = (v / step).round() * step;
    return snapped.clamp(config.min, config.max).toInt();
  }

  @override
  Widget build(BuildContext context) {
    assert(config.domain == SliderDomainType.timeSeconds);
    final theme = Theme.of(context);
    final min = config.min;
    final max = config.max;
    final divisions = config.divisions != null && config.divisions! > 0
        ? config.divisions
        : ((max - min) ~/ config.step).clamp(1, 3600);

    final clamped = seconds.clamp(min.toInt(), max.toInt());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with current value
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            Semantics(
              label: label,
              value: formatMmSs(clamped),
              child: Text(
                formatMmSs(clamped),
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            showValueIndicator: ShowValueIndicator.always,
          ),
          child: Slider(
            value: clamped.toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            label: formatMmSs(clamped),
            onChanged: (v) => onChanged(_snap(v)),
          ),
        ),
        // Min/Max labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatMmSs(min.toInt()), style: theme.textTheme.labelSmall),
            Text(formatMmSs(max.toInt()), style: theme.textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}
