import 'package:intl/intl.dart';

/// Money is held as a `double` of major units (rupees, not paisa) and rounded
/// to 2dp at every boundary. Formatting lives here so the symbol can be changed
/// once in Settings and take effect everywhere.
class CurrencyFormatter {
  CurrencyFormatter._();

  static String symbol = 'Rs.';

  static final NumberFormat _plain = NumberFormat('#,##0.00');
  static final NumberFormat _compact = NumberFormat.compact();

  static String format(num value) => '$symbol ${_plain.format(value)}';

  static String formatPlain(num value) => _plain.format(value);

  /// For dashboard tiles where "1.2M" beats a 9-digit number.
  static String formatCompact(num value) => '$symbol ${_compact.format(value)}';

  /// Signed, for ledger rows: +1,200.00 / -450.00
  static String formatSigned(num value) {
    final sign = value >= 0 ? '+' : '-';
    return '$sign$symbol ${_plain.format(value.abs())}';
  }

  static double round(num value) => (value * 100).roundToDouble() / 100;

  static double parse(String? input) {
    if (input == null || input.trim().isEmpty) return 0;
    return double.tryParse(input.replaceAll(',', '').trim()) ?? 0;
  }
}
