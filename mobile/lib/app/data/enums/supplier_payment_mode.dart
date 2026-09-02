import 'domain_tone.dart';

/// How the shop paid a supplier.
///
/// There is deliberately no CREDIT here, unlike [SalePaymentMode]. An unpaid
/// purchase is simply a purchase with no payment rows against it - credit is
/// the *absence* of a payment, not a kind of payment.
enum SupplierPaymentMode {
  cash('CASH', 'Cash', DomainTone.success),
  cheque('CHEQUE', 'Cheque', DomainTone.warning),
  bankTransfer('BANK_TRANSFER', 'Bank transfer', DomainTone.info),
  other('OTHER', 'Other', DomainTone.neutral);

  const SupplierPaymentMode(this.value, this.label, this.tone);

  final String value;
  final String label;
  final DomainTone tone;

  /// Cheque number and cheque date are recorded only for this mode, and it is
  /// the only mode that normally starts life as ISSUED rather than CLEARED.
  bool get isCheque => this == SupplierPaymentMode.cheque;

  /// Bank and wallet transfers carry a reference number instead.
  bool get hasReference => this == SupplierPaymentMode.bankTransfer;

  static SupplierPaymentMode fromValue(String? value) =>
      SupplierPaymentMode.values.firstWhere(
        (e) => e.value == value,
        orElse: () => SupplierPaymentMode.cash,
      );
}
