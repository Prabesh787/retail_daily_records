/// What kind of place the shop's money sits in.
///
/// Cash is one fixed account; a shop adds as many banks and wallets as it uses.
enum AccountType {
  cash('CASH', 'Cash'),
  bank('BANK', 'Bank'),
  wallet('WALLET', 'Wallet / QR');

  const AccountType(this.value, this.label);

  final String value;
  final String label;

  static AccountType fromValue(String? value) => AccountType.values.firstWhere(
    (e) => e.value == value,
    orElse: () => AccountType.bank,
  );
}
