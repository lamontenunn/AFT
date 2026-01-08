import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:aft_firebase_app/features/aft/logic/scoring_service.dart'
    show AftEvent;
import 'package:aft_firebase_app/theme/army_colors.dart';
import 'package:aft_firebase_app/widgets/aft_svg_icon.dart';

class ProctorInstructionsTab extends StatefulWidget {
  const ProctorInstructionsTab({super.key});

  @override
  State<ProctorInstructionsTab> createState() => _ProctorInstructionsTabState();
}

class _ProctorInstructionsTabState extends State<ProctorInstructionsTab> {
  AftEvent _selectedEvent = AftEvent.mdl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eventData = _eventInstructions[_selectedEvent]!;

    return Column(
      children: [
        _InstructionSection(
          icon: const Icon(Icons.assignment_outlined),
          title: 'Test Instructions',
          subtitle: 'Overview, safety, sequence, equipment',
          bullets: _testSummaryBullets,
          onCopy: () => _copySummary(
            context,
            'Test Instructions',
            _testSummaryBullets,
          ),
          onShowReference: () => _showReferenceSheet(
            context,
            'Test Instructions',
            _testReferenceBody,
          ),
        ),
        const SizedBox(height: 10),
        _InstructionSection(
          icon: const Icon(Icons.route_outlined),
          title: 'Lane Layout',
          subtitle: 'Lane setup',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SDC lane setup',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const _BulletList(
                items: [
                  'Measure a straight 25 m lane (3 m wide if space allows).',
                  'Mark start/finish and 25 m turn lines clearly.',
                  'Leave space beyond lines for safe turns and sprint-through.',
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Practical marking checklist',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const _BulletList(
                items: [
                  'Measure 25 m with a tape.',
                  'Mark the start line and 25 m line clearly (cones, paint, chalk, or tape).',
                  'Place sled and kettlebells behind the start line so they do not creep forward.',
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
          bullets: _laneSummaryBullets,
          onCopy: () => _copySummary(
            context,
            'Lane Layout',
            _laneSummaryBullets,
          ),
          onShowReference: () => _showReferenceSheet(
            context,
            'Lane Layout',
            _laneReferenceBody,
          ),
        ),
        const SizedBox(height: 10),
        _InstructionSection(
          icon: const Icon(Icons.fact_check_outlined),
          title: 'Event Instructions',
          subtitle: 'Standards, faults, termination',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<AftEvent>(
                segments: [
                  _eventIconSegment(
                    event: AftEvent.mdl,
                    label: 'MDL',
                    asset: 'assets/icons/deadlift.svg',
                  ),
                  _eventIconSegment(
                    event: AftEvent.pushUps,
                    label: 'HRP',
                    asset: 'assets/icons/pushup.svg',
                  ),
                  _eventIconSegment(
                    event: AftEvent.sdc,
                    label: 'SDC',
                    asset: 'assets/icons/dragcarry.svg',
                  ),
                  _eventIconSegment(
                    event: AftEvent.plank,
                    label: 'PLK',
                    asset: 'assets/icons/plank.svg',
                  ),
                  _eventIconSegment(
                    event: AftEvent.run2mi,
                    label: '2MR',
                    asset: 'assets/icons/run.svg',
                  ),
                ],
                selected: {_selectedEvent},
                onSelectionChanged: (sel) {
                  if (sel.isEmpty) return;
                  setState(() => _selectedEvent = sel.first);
                },
              ),
              const SizedBox(height: 8),
              _EventInstructionCard(data: eventData),
            ],
          ),
          onCopy: () => _copySummary(
            context,
            'Event Instructions - ${eventData.title}',
            eventData.bullets,
          ),
          onShowReference: () => _showReferenceSheet(
            context,
            'Event Instructions - ${eventData.title}',
            eventData.referenceBody,
          ),
        ),
      ],
    );
  }

  void _copySummary(BuildContext context, String title, List<String> bullets) {
    final buffer = StringBuffer('$title\n');
    for (final item in bullets) {
      buffer.writeln('- $item');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied $title')),
    );
  }

  void _showReferenceSheet(BuildContext context, String title, String body) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: theme.colorScheme.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(
                    body,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ButtonSegment<AftEvent> _eventIconSegment({
    required AftEvent event,
    required String label,
    required String asset,
  }) {
    return ButtonSegment<AftEvent>(
      value: event,
      label: Tooltip(
        message: label,
        child: AftSvgIcon(
          asset,
          size: 20,
          padding: const EdgeInsets.all(0),
          colorFilter: const ColorFilter.mode(
            ArmyColors.gold,
            BlendMode.srcIn,
          ),
          semanticLabel: label,
        ),
      ),
    );
  }
}

class _InstructionSection extends StatelessWidget {
  const _InstructionSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.body,
    this.bullets,
    required this.onShowReference,
    required this.onCopy,
  });

  final Widget icon;
  final String title;
  final String subtitle;
  final Widget? body;
  final List<String>? bullets;
  final VoidCallback onShowReference;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: _SectionIcon(icon: icon),
          title: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          children: [
            if (body != null) body!,
            if (bullets != null) _BulletList(items: bullets!),
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton(
                  onPressed: onShowReference,
                  child: const Text('Show full reference'),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Copy summary',
                  icon: const Icon(Icons.copy_all_outlined, size: 16),
                  onPressed: onCopy,
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints.tightFor(width: 28, height: 28),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
class _SectionIcon extends StatelessWidget {
  const _SectionIcon({required this.icon});

  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Center(
        child: IconTheme(
          data: IconThemeData(
            size: 20,
            color: theme.colorScheme.onSurface,
          ),
          child: icon,
        ),
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('- ', style: style),
                Expanded(child: Text(item, style: style)),
              ],
            ),
          ),
      ],
    );
  }
}

class _EventInstructionCard extends StatelessWidget {
  const _EventInstructionCard({required this.data});

  final _EventInstruction data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.onSurface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AftSvgIcon(
                data.iconAsset,
                size: 20,
                padding: const EdgeInsets.all(0),
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _BulletList(items: data.bullets),
        ],
      ),
    );
  }
}

class _EventInstruction {
  const _EventInstruction({
    required this.title,
    required this.iconAsset,
    required this.bullets,
    required this.referenceBody,
  });

  final String title;
  final String iconAsset;
  final List<String> bullets;
  final String referenceBody;
}

const List<String> _testSummaryBullets = [
  'Overview: confirm roster, standards, and event order before start.',
  'Safety: inspect equipment, clear lanes, and stop unsafe attempts.',
  'Sequence: MDL -> HRP -> SDC -> PLK -> 2MR (per SOP).',
  'Equipment: bar, plates, collars, sled, kettlebells, cones, stopwatch.',
  'Scoring: record results immediately and verify before saving.',
  'Rest: follow unit rest windows and hydration guidance.',
];

const String _testReferenceBody = '''
Overview
- Verify roster, test standard (General/Combat), and participant data.
- Brief the order of events and how scores are recorded.

Safety
- Inspect bar, plates, sled, kettlebells, and lane surfaces.
- Stop any attempt with unsafe form or equipment issues.

Sequence
- MDL -> HRP -> SDC -> PLK -> 2MR (adjust only per unit SOP).

Equipment checklist
- Bar (60 lb), plates, collars, sled + strap, kettlebells, cones, stopwatch.

Scoring and rest
- Record immediately and confirm with the participant.
- Follow rest windows and hydration guidance between events.
''';

const List<String> _laneSummaryBullets = [
  'Measure a straight 25 m lane (3 m wide if possible).',
  'Mark start/finish and 25 m turn lines clearly.',
  'Leave space beyond lines for safe turns and sprint-through.',
  'Stage sleds and kettlebells behind the start line.',
  'Keep graders positioned to see start and turn.',
];

const String _laneReferenceBody = '''
Lane layout
- Measure a straight 25 m lane (3 m wide if space allows).
- Mark start/finish and 25 m turn lines clearly.
- Leave extra space beyond lines for safe turns and sprint-through.
- Position graders to see the start and turn line.

Marking checklist
- Measure 25 m with a tape.
- Mark the start line and 25 m line clearly (cones, paint, chalk, or tape).
- Place sled and kettlebells behind the start line so they do not creep forward.
''';

const Map<AftEvent, _EventInstruction> _eventInstructions = {
  AftEvent.mdl: _EventInstruction(
    title: 'MDL - 3 Rep Deadlift',
    iconAsset: 'assets/icons/deadlift.svg',
    bullets: [
      'Standards: bar starts on floor; lift under control.',
      'Standards: hips and knees fully extend at the top.',
      'Common faults: bouncing or resting the bar on thighs.',
      'Common faults: incomplete lockout or uncontrolled descent.',
      'Termination: unsafe form or proctor stop.',
    ],
    referenceBody: '''
Standards
- Bar starts on the floor and is lifted under control.
- Hips and knees reach full extension at the top.

Common faults
- Bouncing the bar or resting it on the thighs.
- Failing to reach full lockout.

Termination
- Unsafe form, loss of control, or proctor stop.
''',
  ),
  AftEvent.pushUps: _EventInstruction(
    title: 'HRP - Hand-Release Push-up',
    iconAsset: 'assets/icons/pushup.svg',
    bullets: [
      'Standards: body stays straight in the front-leaning rest.',
      'Standards: hands clearly leave the floor each rep.',
      'Common faults: hips sagging or knees touching.',
      'Common faults: partial lockout or no hand release.',
      'Termination: unsafe form or time expires (2:00).',
    ],
    referenceBody: '''
Standards
- Maintain a straight body position in front-leaning rest.
- Hands clearly leave the floor at the bottom of each rep.

Common faults
- Hips sagging, knees touching, or partial lockout.
- No visible hand release.

Termination
- Unsafe form or time expires (2:00).
''',
  ),
  AftEvent.sdc: _EventInstruction(
    title: 'SDC - Sprint-Drag-Carry',
    iconAsset: 'assets/icons/dragcarry.svg',
    bullets: [
      'Standards: complete all segments in order.',
      'Standards: touch the line at each turn.',
      'Common faults: missing the line or cutting turns.',
      'Common faults: dropping kettlebells outside the turn zone.',
      'Termination: unsafe movement or proctor stop.',
    ],
    referenceBody: '''
Standards
- Complete all five segments in order.
- Touch the line at each turn.

Common faults
- Missing the line or cutting the turn.
- Dropping kettlebells outside the turn zone.

Termination
- Unsafe movement or proctor stop.
''',
  ),
  AftEvent.plank: _EventInstruction(
    title: 'PLK - Plank',
    iconAsset: 'assets/icons/plank.svg',
    bullets: [
      'Standards: head, torso, and legs stay aligned.',
      'Standards: elbows under shoulders; forearms on ground.',
      'Common faults: hips sagging or piking.',
      'Common faults: knees or hands touching the ground.',
      'Termination: form break after warning or proctor stop.',
    ],
    referenceBody: '''
Standards
- Head, torso, and legs stay aligned.
- Elbows under shoulders with forearms on the ground.

Common faults
- Hips sagging, piking, or knees touching.

Termination
- Form break after warning or proctor stop.
''',
  ),
  AftEvent.run2mi: _EventInstruction(
    title: '2MR - 2 Mile Run',
    iconAsset: 'assets/icons/run.svg',
    bullets: [
      'Standards: complete the full course distance.',
      'Standards: time stops at the finish line.',
      'Common faults: leaving the course or shorting distance.',
      'Common faults: obstructing other runners.',
      'Termination: unsafe conditions or medical stop.',
    ],
    referenceBody: '''
Standards
- Complete the full course distance.
- Time stops when the finish line is crossed.

Common faults
- Leaving the course or shorting distance.
- Obstructing other runners.

Termination
- Unsafe conditions or medical stop.
''',
  ),
};
