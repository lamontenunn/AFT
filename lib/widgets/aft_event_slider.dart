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
    final min = config.min;
    final snapped = min + (((v - min) / step).round() * step);
    return snapped.clamp(min, config.max).toInt();
  }

  @override
  Widget build(BuildContext context) {
    assert(config.domain == SliderDomainType.integer);
    final theme = Theme.of(context);
    final min = config.min;
    final max = config.max;
    final int? divisions = config.divisions; // discrete ticks to ensure endpoints are reachable

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
    this.reversed = false,
  });

  final String label;
  final int seconds; // current value in seconds
  final SliderConfig config;
  final ValueChanged<int> onChanged;
  final bool reversed;

  int _snap(double v) {
    final step = config.step;
    final min = config.min;
    final snapped = min + (((v - min) / step).round() * step);
    return snapped.clamp(min, config.max).toInt();
  }

  @override
  Widget build(BuildContext context) {
    assert(config.domain == SliderDomainType.timeSeconds);
    final theme = Theme.of(context);
    final min = config.min;
    final max = config.max;
    // Use 1-second tick granularity so endpoints are exactly reachable,
    // while still snapping to config.step in onChanged.
    final int divisions = (max - min).toInt();

    final clamped = seconds.clamp(min.toInt(), max.toInt());
    // UI value mapping: when reversed, rightward drag lowers time (higher score).
    final double uiValue = reversed ? (min + max - clamped) : clamped.toDouble();

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
            value: uiValue,
            min: min,
            max: max,
            divisions: divisions,
            label: formatMmSs(clamped),
            onChanged: (v) {
              // Snap in the seconds domain so endpoints (min/max) are always reachable,
              // then apply clamping. Do the reverse mapping BEFORE snapping.
              final secondsRaw = reversed ? (min + max - v) : v;
              final snapped = _snap(secondsRaw);
              onChanged(snapped);
            },
          ),
        ),
        // Min/Max labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              reversed ? formatMmSs(max.toInt()) : formatMmSs(min.toInt()),
              style: theme.textTheme.labelSmall,
            ),
            Text(
              reversed ? formatMmSs(min.toInt()) : formatMmSs(max.toInt()),
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ],
    );
  }
}
