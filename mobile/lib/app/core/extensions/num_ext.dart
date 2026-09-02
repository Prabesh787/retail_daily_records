import '../utils/currency_formatter.dart';

extension NumX on num {
  String get money => CurrencyFormatter.format(this);
  String get moneyPlain => CurrencyFormatter.formatPlain(this);
  String get moneyCompact => CurrencyFormatter.formatCompact(this);
  String get moneySigned => CurrencyFormatter.formatSigned(this);
  double get rounded => CurrencyFormatter.round(this);
}
