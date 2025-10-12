import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aft_firebase_app/theme/army_colors.dart';
import 'package:aft_firebase_app/widgets/aft_pill.dart';
import 'package:aft_firebase_app/widgets/aft_choice_chip.dart';
import 'package:aft_firebase_app/widgets/aft_event_card.dart';
import 'package:aft_firebase_app/widgets/aft_score_ring.dart';

/// Home screen layout (first page)
/// - Total card with right-side pass/fail box (gold outline)
/// - Context row card: Age dropdown; Sex chips; Test Date pill (no picker)
/// - Event cards: MDL, HR Push-ups, Sprint-Drag-Carry (with inputs)
/// For this milestone, event score rings show fixed placeholders (82/74/68)
/// and Total sums those placeholders.
class FeatureHomeScreen extends StatefulWidget {
  const FeatureHomeScreen({super.key});

  @override
  State<FeatureHomeScreen> createState() => _FeatureHomeScreenState();
}

class _FeatureHomeScreenState extends State<FeatureHomeScreen> {
  // Context row
  int _age = 25;
  bool _isMale = true;
  DateTime? _testDate; // no picker yet

  // Inputs
  final _mdlController = TextEditingController();
  final _puController = TextEditingController();
  final _sdcController = TextEditingController(); // mm:ss
  String? _mdlError;
  String? _puError;
  String? _sdcError;

  // Placeholder scores (live in ring)
  static const int _mdlScore = 82;
  static const int _puScore = 74;
  static const int _sdcScore = 68;

  int? get _totalPlaceholder => _mdlScore + _puScore + _sdcScore;

  @override
  void dispose() {
    _mdlController.dispose();
    _puController.dispose();
    _sdcController.dispose();
    super.dispose();
  }

  void _validateMdl(String value) {
    if (value.isEmpty) {
      setState(() => _mdlError = null);
      return;
    }
    final v = int.tryParse(value);
    if (v == null || v < 0) {
      setState(() => _mdlError = 'Enter a non-negative number');
    } else {
      setState(() => _mdlError = null);
    }
  }

  void _validatePu(String value) {
    if (value.isEmpty) {
      setState(() => _puError = null);
      return;
    }
    final v = int.tryParse(value);
    if (v == null || v < 0) {
      setState(() => _puError = 'Enter a non-negative number');
    } else {
      setState(() => _puError = null);
    }
  }

  void _validateSdc(String value) {
    if (value.isEmpty) {
      setState(() => _sdcError = null);
      return;
    }
    // Expect mm:ss, with mm and ss numeric, 0-59 for ss
    final parts = value.split(':');
    if (parts.length != 2) {
      setState(() => _sdcError = 'Use mm:ss');
      return;
    }
    final m = int.tryParse(parts[0]);
    final s = int.tryParse(parts[1]);
    if (m == null || s == null || m < 0 || s < 0 || s > 59) {
      setState(() => _sdcError = 'Use mm:ss');
    } else {
      setState(() => _sdcError = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const SizedBox(height: 12),

        // Total card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _totalPlaceholder == null ? 'Total: —' : 'Total: ${_totalPlaceholder}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: ShapeDecoration(
                      shape: StadiumBorder(
                        side: BorderSide(color: ArmyColors.gold, width: 1.2),
                      ),
                    ),
                    child: Text(
                      '—', // Placeholder pass/fail
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Context row card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Context', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Age dropdown as pill
                      AftPill(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Age'),
                            const SizedBox(width: 8),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _age,
                                dropdownColor: cs.surface,
                                items: List.generate(63, (i) => 18 + i)
                                    .map((a) => DropdownMenuItem(
                                          value: a,
                                          child: Text('$a'),
                                        ))
                                    .toList(),
                                onChanged: (v) => setState(() => _age = v ?? _age),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Sex chips
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AftChoiceChip(
                            label: 'Male',
                            selected: _isMale,
                            onSelected: (val) => setState(() => _isMale = true),
                          ),
                          const SizedBox(width: 8),
                          AftChoiceChip(
                            label: 'Female',
                            selected: !_isMale,
                            onSelected: (val) => setState(() => _isMale = false),
                          ),
                        ],
                      ),

                      // Test date pill (no picker)
                      AftPill(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Test Date'),
                            const SizedBox(width: 8),
                            Text(
                              _testDate == null
                                  ? '—'
                                  : _fmtDate(_testDate!),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // MDL card
        AftEventCard(
          title: '3-Rep Max Deadlift (MDL)',
          icon: Icons.fitness_center,
          trailing: const AftScoreRing(score: _mdlScore),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Weight (lbs)', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 6),
              TextField(
                controller: _mdlController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _validateMdl,
                decoration: InputDecoration(
                  hintText: 'e.g., 185',
                  errorText: _mdlError,
                  suffixText: 'lbs',
                ),
              ),
            ],
          ),
        ),

        // Push-ups card
        AftEventCard(
          title: 'Hand-Release Push-ups',
          icon: Icons.accessibility_new,
          trailing: const AftScoreRing(score: _puScore),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Repetitions', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 6),
              TextField(
                controller: _puController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _validatePu,
                decoration: InputDecoration(
                  hintText: 'e.g., 30',
                  errorText: _puError,
                ),
              ),
            ],
          ),
        ),

        // Sprint-Drag-Carry card
        AftEventCard(
          title: 'Sprint-Drag-Carry',
          icon: Icons.timer_outlined,
          trailing: const AftScoreRing(score: _sdcScore),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Time (mm:ss)', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 6),
              TextField(
                controller: _sdcController,
                keyboardType: TextInputType.number,
                inputFormatters: [_MmSsFormatter()],
                onChanged: _validateSdc,
                decoration: InputDecoration(
                  hintText: 'e.g., 01:45',
                  errorText: _sdcError,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
      ],
    );
  }

  String _fmtDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}

/// Basic mm:ss input formatter.
/// - Only digits are accepted; a colon is inserted after 2 digits
/// - Limits length to 5 (mm:ss)
class _MmSsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 4) text = text.substring(0, 4);

    String formatted;
    if (text.length <= 2) {
      formatted = text;
    } else {
      formatted = '${text.substring(0, 2)}:${text.substring(2)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
