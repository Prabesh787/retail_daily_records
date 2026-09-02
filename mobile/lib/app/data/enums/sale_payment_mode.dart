import 'domain_tone.dart';

/// How a customer settled a sale.
///
/// One sale may be split across several of these - part cash, part credit - so
/// these are rows against the sale rather than a column on it.
///
/// CREDIT exists here and not in [SupplierPaymentMode]: on the sale side the
/// shop needs to record explicitly that a customer took goods without paying,
/// because there may be no other row to infer it from.
enum SalePaymentMode {
  cash('CASH', 'Cash', DomainTone.success),
  bank('BANK', 'Bank', DomainTone.info),
  cheque('CHEQUE', 'Cheque', DomainTone.warning),
  credit('CREDIT', 'Credit', DomainTone.danger),
  other('OTHER', 'Other', DomainTone.neutral);

  const SalePaymentMode(this.value, this.label, this.tone);

  final String value;
  final String label;
  final DomainTone tone;

  /// Credit is a promise, not takings. Counting it as money received is how a
  /// day's till stops matching the day book.
  bool get isSettled => this != SalePaymentMode.credit;

  bool get isCheque => this == SalePaymentMode.cheque;

  static SalePaymentMode fromValue(String? value) =>
      SalePaymentMode.values.firstWhere(
        (e) => e.value == value,
        orElse: () => SalePaymentMode.cash,
      );
}
