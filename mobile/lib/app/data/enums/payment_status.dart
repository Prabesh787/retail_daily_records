import 'domain_tone.dart';

/// The lifecycle of a payment instrument.
///
/// This is what makes a future-dated cheque expressible. A cheque handed over
/// today for a date three weeks out is recorded immediately, but it is not yet
/// a bank transaction:
///
///   ISSUED    - recorded, not yet realised (typically a future-dated cheque)
///   CLEARED   - the money has actually moved (the normal state for cash)
///   CANCELLED - cancelled, bounced or voided; it settled nothing
///
/// The distinction lets reporting separate three different things: bills with
/// nothing paid against them, money promised but still in the account, and
/// money actually gone.
enum PaymentStatus {
  issued('ISSUED', 'Issued', 'Handed over, not cleared yet', DomainTone.warning),
  cleared('CLEARED', 'Cleared', 'Money has actually moved', DomainTone.success),
  cancelled('CANCELLED', 'Cancelled', 'Voided or bounced', DomainTone.neutral);

  const PaymentStatus(this.value, this.label, this.hint, this.tone);

  final String value;
  final String label;
  final String hint;
  final DomainTone tone;

  /// Whether this payment counts against what the shop owes.
  ///
  /// An issued cheque does: the shop has parted with it. A cancelled one does
  /// not - it settled nothing. This single rule is what the derived supplier
  /// balance turns on, so it lives here rather than being rewritten in every
  /// query that needs it.
  bool get reducesLiability => this != PaymentStatus.cancelled;

  /// Handed over but not yet debited - reported separately from the balance
  /// because that money has not actually left the bank.
  bool get isUncleared => this == PaymentStatus.issued;

  /// Unknown values fall back to CLEARED, matching the column default on the
  /// server. A status this app does not recognise means the two versions have
  /// drifted, which is a bug to fix rather than a state to invent.
  static PaymentStatus fromValue(String? value) =>
      PaymentStatus.values.firstWhere(
        (e) => e.value == value,
        orElse: () => PaymentStatus.cleared,
      );
}
