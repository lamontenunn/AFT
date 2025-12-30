import 'package:flutter/services.dart';

/// Parses a m:ss or mm:ss string into a Duration. Returns null if invalid.
Duration? parseMmSs(String value) {
  final v = value.trim();
  final parts = v.split(':');
  if (parts.length != 2) return null;
  if (parts[0].isEmpty || parts[1].isEmpty) return null;
  // Accept single-digit minutes for SDC/PLK UX (e.g. 3:25).
  // Also still accepts mm:ss.
  final m = int.tryParse(parts[0]);
  // For better typing UX, accept 1-2 digit seconds (3:5 -> 3:05).
  if (parts[1].length < 1 || parts[1].length > 2) return null;
  final s = int.tryParse(parts[1]);
  if (m == null || s == null || m < 0 || s < 0 || s > 59) return null;
  return Duration(minutes: m, seconds: s);
}

/// Formats a Duration as m:ss (minutes not padded; seconds padded).
/// Example: 3:05, 12:34
String formatMmSs(Duration d) {
  final mm = d.inMinutes;
  final ss = d.inSeconds % 60;
  return '${mm.toString()}:${ss.toString().padLeft(2, '0')}';
}

/// Basic time input formatter for m:ss and mm:ss.
/// - Only digits are accepted.
/// - Digits are interpreted as:
///   - 0-2 digits: minutes (still typing)
///   - 3 digits: m:ss
///   - 4 digits: mm:ss
/// - This keeps typing intuitive:
///   - SDC/PLK: 3:25 => type 325
///   - 2MR: 16:45 => type 1645
class MmSsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 4) digits = digits.substring(0, 4);

    String formatted;
    if (digits.length <= 2) {
      formatted = digits;
    } else if (digits.length == 3) {
      // m:ss
      formatted = '${digits.substring(0, 1)}:${digits.substring(1)}';
    } else {
      // mm:ss
      formatted = '${digits.substring(0, 2)}:${digits.substring(2)}';
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
