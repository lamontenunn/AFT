import 'package:flutter/services.dart';

/// Parses a mm:ss string into a Duration. Returns null if invalid.
Duration? parseMmSs(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final m = int.tryParse(parts[0]);
  final s = int.tryParse(parts[1]);
  if (m == null || s == null || m < 0 || s < 0 || s > 59) return null;
  return Duration(minutes: m, seconds: s);
}

/// Formats a Duration as mm:ss (zero-padded).
String formatMmSs(Duration d) {
  final mm = d.inMinutes;
  final ss = d.inSeconds % 60;
  return '${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
}

/// Basic mm:ss input formatter.
/// - Only digits are accepted; a colon is inserted after 2 digits
/// - Limits length to 5 (mm:ss)
class MmSsFormatter extends TextInputFormatter {
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

/// Formats a DateTime as YYYY-MM-DD (zero-padded).
String formatYmd(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

/// Formats a DateTime as YYYY-MM-DD HH:mm (24h, zero-padded).
String formatYmdHm(DateTime d) {
  final date = formatYmd(d);
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '$date $hh:$mm';
}
