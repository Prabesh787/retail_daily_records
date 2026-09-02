import 'domain_tone.dart';

/// How much detail was written down for one sale.
///
/// Both are ONE sale to one customer; the difference is only the paperwork:
///
///   SUMMARY  - the total was enough ("sold 3 shirts, Rs 4,050"), no line items
///   DETAILED - the customer wanted an itemised invoice, so there are items
///
/// A day's takings is not a record of its own; it is the sum of the day's
/// sales. Wire values are the Prisma enum spellings.
enum SaleType {
  summary('SUMMARY', 'Total only', 'Total', DomainTone.neutral),
  detailed('DETAILED', 'Itemised', 'Itemised', DomainTone.info);

  const SaleType(this.value, this.label, this.shortLabel, this.tone);

  final String value;
  final String label;
  final String shortLabel;
  final DomainTone tone;

  /// Only an itemised sale carries invoice lines, and only it may carry an
  /// invoice number the customer was handed.
  bool get hasItems => this == SaleType.detailed;

  static SaleType fromValue(String? value) => SaleType.values.firstWhere(
        (e) => e.value == value,
        orElse: () => SaleType.summary,
      );
}
