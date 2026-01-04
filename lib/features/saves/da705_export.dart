import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:aft_firebase_app/data/aft_repository.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/aft/state/aft_standard.dart';
import 'package:aft_firebase_app/features/aft/utils/formatters.dart';
import 'package:aft_firebase_app/state/settings_state.dart';

const String _da705AssetPath = 'assets/forms/da705_page1.pdf';

Future<void> exportDa705Pdf({
  required BuildContext context,
  required ScoreSet set,
  required DefaultProfileSettings profile,
}) async {
  try {
    final bytes = await _buildDa705PdfBytes(set: set, profile: profile);
    final file = await _writePdfToDocuments(bytes, set);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'DA Form 705',
      text: 'DA Form 705 export from AFT',
    );
    if (context.mounted) {
      await _showSavedLocationDialog(context, file);
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to export DA Form 705')),
    );
  }
}

Future<Uint8List> _buildDa705PdfBytes({
  required ScoreSet set,
  required DefaultProfileSettings profile,
}) async {
  final data = await rootBundle.load(_da705AssetPath);
  final document = PdfDocument(inputBytes: data.buffer.asUint8List());
  final form = document.form;

  final name = _formatName(profile);
  final unit = _trimOrNull(profile.unit);
  final mos = _trimOrNull(profile.mos);
  final payGrade = _trimOrNull(profile.payGrade);

  final testDate = set.profile.testDate ?? set.createdAt;
  final testDateLabel = _formatYmdCompact(testDate);

  final heightIn = _heightInches(profile);
  final weightLb = _weightLbs(profile);
  final bodyFat = profile.bodyFatPercent;

  final comp = set.computed;
  final inputs = set.inputs;

  final isFail = [
    comp?.mdlScore,
    comp?.pushUpsScore,
    comp?.sdcScore,
    comp?.plankScore,
    comp?.run2miScore,
  ].any((s) => s != null && s < 60);
  final isPass = comp != null && !isFail;

  _setText(form, 'Name[0]', name);
  _setText(form, 'Unit_Location[0]', unit);
  _setCheck(form, 'Male[0]', set.profile.sex == AftSex.male);
  _setCheck(form, 'Female[0]', set.profile.sex == AftSex.female);

  _setText(form, 'Test_One_Date[0]', testDateLabel);
  _setText(form, 'Test_One_Body_Composition_Date[0]', testDateLabel);
  _setText(form, 'Test_One_MOS[0]', mos);
  _setText(form, 'Test_One_Rank_Grade[0]', payGrade ?? profile.rankAbbrev);
  _setText(form, 'Test_One_Age[0]', set.profile.age.toString());
  _setText(form, 'Test_One_Height[0]', _formatNumber(heightIn));
  _setText(form, 'Test_One_Weight[0]', _formatNumber(weightLb));
  _setText(form, 'Test_One_Body_Fat[0]', _formatNumber(bodyFat));

  final isCombat = set.profile.standard == AftStandard.combat;
  _setCheck(form, 'Check_Standard_Combat[0]', isCombat);
  _setCheck(form, 'Check_Standard_General[0]', !isCombat);

  _setText(form, 'Test_One_First_Attempt[0]', _formatNumber(inputs.mdlLbs));
  _setCheck(form, 'Test_One_First_Attempt_Check[0]', inputs.mdlLbs != null);
  _setText(form, 'Test_One_Points1[0]', _formatNumber(comp?.mdlScore));

  _setText(form, 'Test_One_Repetitions[0]', _formatNumber(inputs.pushUps));
  _setText(form, 'Test_One_Points3[0]', _formatNumber(comp?.pushUpsScore));

  _setText(form, 'Test_One_Time1[0]', _formatTime(inputs.sdc));
  _setText(form, 'Test_One_Points4[0]', _formatNumber(comp?.sdcScore));

  _setText(form, 'Test_One_Time2[0]', _formatTime(inputs.plank));
  _setText(form, 'Test_One_Points5[0]', _formatNumber(comp?.plankScore));

  _setText(form, 'Test_One_Time3[0]', _formatTime(inputs.run2mi));
  _setText(form, 'Test_One_Points6[0]', _formatNumber(comp?.run2miScore));

  _setText(form, 'Test_One_Total_Points[0]', _formatNumber(comp?.total));

  _setCheck(form, 'Test_One_Go[0]', isPass);
  _setCheck(form, 'Test_One_NoGo[0]', !isPass && comp != null);
  _setCheck(form, 'Test_One_Final_Go[0]', isPass);
  _setCheck(form, 'Test_One_Final_NoGo[0]', !isPass && comp != null);

  form.flattenAllFields();
  final bytes = Uint8List.fromList(document.saveSync());
  document.dispose();
  return bytes;
}

Future<File> _writePdfToDocuments(Uint8List bytes, ScoreSet set) async {
  final dir = await getApplicationDocumentsDirectory();
  final stamp = _formatYmdCompact(set.createdAt);
  final file = File('${dir.path}/da_form_705_$stamp.pdf');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

Future<void> _showSavedLocationDialog(BuildContext context, File file) async {
  final isIos = Platform.isIOS;
  final hint = isIos
      ? 'Files > On My iPhone > Aft Firebase App'
      : 'Your app documents folder';
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Exported DA Form 705'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Saved to: $hint'),
          const SizedBox(height: 8),
          SelectableText(
            file.path,
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: file.path));
            Navigator.of(ctx).pop();
          },
          child: const Text('Copy path'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

PdfField? _findField(PdfForm form, String suffix) {
  for (var i = 0; i < form.fields.count; i += 1) {
    final field = form.fields[i];
    final name = field.name ?? '';
    if (name == suffix || name.endsWith(suffix)) {
      return field;
    }
  }
  return null;
}

void _setText(PdfForm form, String suffix, String? value) {
  final v = _trimOrNull(value);
  if (v == null) return;
  final field = _findField(form, suffix);
  if (field is PdfTextBoxField) {
    field.text = v;
  }
}

void _setCheck(PdfForm form, String suffix, bool checked) {
  final field = _findField(form, suffix);
  if (field is PdfCheckBoxField) {
    field.isChecked = checked;
  }
}

String? _trimOrNull(String? value) {
  if (value == null) return null;
  final v = value.trim();
  return v.isEmpty ? null : v;
}

String _formatName(DefaultProfileSettings profile) {
  final last = _trimOrNull(profile.lastName);
  final first = _trimOrNull(profile.firstName);
  final mi = _trimOrNull(profile.middleInitial);

  if (last == null && first == null && mi == null) return '';

  final buffer = StringBuffer();
  if (last != null) buffer.write(last);
  if (first != null) {
    if (buffer.isNotEmpty) buffer.write(', ');
    buffer.write(first);
  }
  if (mi != null) {
    buffer.write(' ${mi[0].toUpperCase()}.');
  }
  return buffer.toString();
}

String _formatYmdCompact(DateTime date) {
  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');
  return '${date.year}$mm$dd';
}

String? _formatNumber(num? value) {
  if (value == null) return null;
  final v = value.toStringAsFixed(1);
  return v.endsWith('.0') ? v.substring(0, v.length - 2) : v;
}

String? _formatTime(Duration? value) {
  if (value == null) return null;
  return formatMmSs(value);
}

double? _heightInches(DefaultProfileSettings profile) {
  final height = profile.height;
  if (height == null) return null;
  if (profile.measurementSystem == MeasurementSystem.metric) {
    return height / 2.54;
  }
  return height;
}

double? _weightLbs(DefaultProfileSettings profile) {
  final weight = profile.weight;
  if (weight == null) return null;
  if (profile.measurementSystem == MeasurementSystem.metric) {
    return weight * 2.2046226218;
  }
  return weight;
}
