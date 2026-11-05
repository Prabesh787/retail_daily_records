import '../../data/enums/sale_payment_mode.dart';
import '../../data/enums/supplier_payment_mode.dart';

/// How money changed hands, in the words the forms use.
///
/// One set of choices on every form, so a shopkeeper who has learned the sale
/// screen already knows the other three. The stored enums stay as they are;
/// these map onto them.
enum PayMethod {
  cash('Cash'),
  bank('Bank'),
  cheque('Cheque'),
  credit('Credit');

  const PayMethod(this.label);

  final String label;

  SalePaymentMode get saleMode => switch (this) {
    PayMethod.cash => SalePaymentMode.cash,
    PayMethod.bank => SalePaymentMode.bank,
    PayMethod.cheque => SalePaymentMode.cheque,
    PayMethod.credit => SalePaymentMode.credit,
  };

  /// There is no credit on this side: an unpaid bill has no payment row at all,
  /// so callers never ask for one.
  SupplierPaymentMode get paymentMode => switch (this) {
    PayMethod.bank => SupplierPaymentMode.bankTransfer,
    PayMethod.cheque => SupplierPaymentMode.cheque,
    _ => SupplierPaymentMode.cash,
  };

  /// Cash sits in one place, so only these ask which account.
  bool get needsAccount => this == PayMethod.bank;

  bool get isCheque => this == PayMethod.cheque;
  bool get isCredit => this == PayMethod.credit;
}
