import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aft_firebase_app/features/aft/logic/slider_config.dart';

class _TickBar extends StatelessWidget {
  const _TickBar({
    required this.min,
    required this.max,
    this.thresholds,
    this.formatLabel,
  });
  final double min;
  final double max;
  final ScoreThresholds? thresholds;
  final String Function(int)? formatLabel;

  @override
  Widget build(BuildContext context) {
    if (thresholds == null) return const SizedBox.shrink();
    final width = 220.0; // compact non-interactive bar width
    final height = 8.0;

    double pos(int v) => ((v - min) / (max - min)).clamp(0, 1);

    return Semantics(
      label: 'Threshold ticks',
      hint: formatLabel == null
          ? 'Ticks at 60, 90, 100 points'
          : 'Ticks at 60, 90, 100 points: '
              '${formatLabel!(thresholds!.p60)}, '
              '${formatLabel!(thresholds!.p90)}, '
              '${formatLabel!(thresholds!.p100)}',
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _TickPainter(
            positions: [
              pos(thresholds!.p60),
              pos(thresholds!.p90),
              pos(thresholds!.p100),
            ],
          ),
        ),
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  _TickPainter({required this.positions});
  final List<double> positions; // 0..1

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = Colors.black.withOpacity(0.45);

    final y = size.height / 2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), track);

    for (final p in positions) {
      final x = p * size.width;
      canvas.drawCircle(Offset(x, y), 2.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _TickPainter old) => old.positions != positions;
}

class AftIntSlider extends StatefulWidget {
  const AftIntSlider({
    super.key,
    required this.label,
    required this.value,
    required this.config,
    required this.onChanged,
    this.suffix,
    this.thresholds,
    this.showTicks = true,
  });

  final String label;
  final int value;
  final SliderConfig config;
  final ValueChanged<int> onChanged;
  final String? suffix;
  final ScoreThresholds? thresholds;
  final bool showTicks;

  @override
  State<AftIntSlider> createState() => _AftIntSliderState();
}

class _AftIntSliderState extends State<AftIntSlider> {
  int _bucketFor(int v) {
    final t = widget.thresholds;
    if (t == null) return -1;
    if (v >= t.p100) return 100;
    if (v >= t.p90) return 90;
    if (v >= t.p60) return 60;
    return 0;
  }

  int? _lastBucket;

  int _snap(double v) {
    final step = widget.config.step;
    final min = widget.config.min;
    final snapped = min + (((v - min) / step).round() * step);
    return snapped.clamp(min, widget.config.max).toInt();
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.config.domain == SliderDomainType.integer);
    final theme = Theme.of(context);
    final min = widget.config.min;
    final max = widget.config.max;
    final int? divisions = widget.config.divisions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.label, style: theme.textTheme.bodyMedium),
            Semantics(
              label: widget.label,
              value: widget.suffix == null
                  ? '${widget.value}'
                  : '${widget.value} ${widget.suffix}',
              child: Text(
                widget.suffix == null
                    ? '${widget.value}'
                    : '${widget.value} ${widget.suffix}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            showValueIndicator: ShowValueIndicator.onlyForDiscrete,
            trackHeight: 2.5,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: widget.value.clamp(min.toInt(), max.toInt()).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            label: widget.suffix == null
                ? '${widget.value}'
                : '${widget.value} ${widget.suffix}',
            onChanged: (v) {
              final snapped = _snap(v);
              final b = _bucketFor(snapped);
              if (b != _lastBucket && b != -1) {
                if (b == 100)
                  HapticFeedback.lightImpact();
                else
                  HapticFeedback.selectionClick();
                _lastBucket = b;
              }
              widget.onChanged(snapped);
            },
          ),
        ),
        if (widget.showTicks) ...[
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: _TickBar(
              min: min,
              max: max,
              thresholds: widget.thresholds,
            ),
          ),
        ],
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                widget.suffix == null
                    ? '${min.toInt()}'
                    : '${min.toInt()} ${widget.suffix}',
                style: theme.textTheme.labelSmall),
            Text(
                widget.suffix == null
                    ? '${max.toInt()}'
                    : '${max.toInt()} ${widget.suffix}',
                style: theme.textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}

class AftTimeSlider extends StatefulWidget {
  const AftTimeSlider({
    super.key,
    required this.label,
    required this.seconds,
    required this.config,
    required this.onChanged,
    this.reversed = false,
    this.thresholds,
    this.showTicks = true,
  });

  final String label;
  final int seconds; // current value in seconds
  final SliderConfig config;
  final ValueChanged<int> onChanged;
  final bool reversed;
  final ScoreThresholds? thresholds;
  final bool showTicks;

  @override
  State<AftTimeSlider> createState() => _AftTimeSliderState();
}

class _AftTimeSliderState extends State<AftTimeSlider> {
  int _bucketFor(int v) {
    final t = widget.thresholds;
    if (t == null) return -1;
    if (widget.reversed) {
      // lower is better
      if (v <= t.p100) return 100;
      if (v <= t.p90) return 90;
      if (v <= t.p60) return 60;
      return 0;
    } else {
      // higher is better (plank)
      if (v >= t.p100) return 100;
      if (v >= t.p90) return 90;
      if (v >= t.p60) return 60;
      return 0;
    }
  }

  int? _lastBucket;

  int _snap(double v) {
    final step = widget.config.step;
    final min = widget.config.min;
    final snapped = min + (((v - min) / step).round() * step);
    return snapped.clamp(min, widget.config.max).toInt();
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.config.domain == SliderDomainType.timeSeconds);
    final theme = Theme.of(context);
    final min = widget.config.min;
    final max = widget.config.max;
    final divisions = widget.config.divisions;
    final int? safeDivisions =
        (divisions != null && divisions > 0) ? divisions : null;

    final clamped = widget.seconds.clamp(min.toInt(), max.toInt());
    final double uiValue =
        widget.reversed ? (min + max - clamped) : clamped.toDouble();

    String format(int s) => formatMmSs(s);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.label, style: theme.textTheme.bodyMedium),
            Semantics(
              label: widget.label,
              value: format(clamped),
              child: Text(
                format(clamped),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            showValueIndicator: ShowValueIndicator.onlyForDiscrete,
            trackHeight: 2.5,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: uiValue,
            min: min,
            max: max,
            divisions: safeDivisions,
            label: format(clamped),
            onChanged: (v) {
              final secondsRaw = widget.reversed ? (min + max - v) : v;
              final snapped = _snap(secondsRaw);
              final b = _bucketFor(snapped);
              if (b != _lastBucket && b != -1) {
                if (b == 100)
                  HapticFeedback.lightImpact();
                else
                  HapticFeedback.selectionClick();
                _lastBucket = b;
              }
              widget.onChanged(snapped);
            },
          ),
        ),
        if (widget.showTicks) ...[
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: _TickBar(
              min: widget.reversed ? min : min,
              max: widget.reversed ? max : max,
              thresholds: widget.thresholds,
              formatLabel: (s) => format(s),
            ),
          ),
        ],
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.reversed ? format(max.toInt()) : format(min.toInt()),
              style: theme.textTheme.labelSmall,
            ),
            Text(
              widget.reversed ? format(min.toInt()) : format(max.toInt()),
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ],
    );
  }
}
