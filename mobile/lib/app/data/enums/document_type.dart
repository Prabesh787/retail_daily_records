/// What a piece of scanned evidence is.
///
/// Attachments are polymorphic - a scan hangs off a purchase, a supplier
/// payment or a sale - so this says what the paper actually is, independently
/// of which record it is filed under.
enum DocumentType {
  purchaseBill('PURCHASE_BILL', 'Purchase bill'),
  supplierPaymentReceipt('SUPPLIER_PAYMENT_RECEIPT', 'Payment receipt'),
  chequeCopy('CHEQUE_COPY', 'Cheque copy'),
  saleInvoice('SALE_INVOICE', 'Sale invoice'),
  other('OTHER', 'Other document');

  const DocumentType(this.value, this.label);

  final String value;
  final String label;

  static DocumentType fromValue(String? value) =>
      DocumentType.values.firstWhere(
        (e) => e.value == value,
        orElse: () => DocumentType.other,
      );
}

/// Which kind of record an attachment hangs off.
enum AttachmentEntityType {
  purchase('PURCHASE', 'Purchase'),
  supplierPayment('SUPPLIER_PAYMENT', 'Supplier payment'),
  sale('SALE', 'Sale');

  const AttachmentEntityType(this.value, this.label);

  final String value;
  final String label;

  static AttachmentEntityType fromValue(String? value) =>
      AttachmentEntityType.values.firstWhere(
        (e) => e.value == value,
        orElse: () => AttachmentEntityType.purchase,
      );
}
