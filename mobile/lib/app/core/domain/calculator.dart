import 'money.dart';

/// The arithmetic behind Quick Sale's keypad.
///
/// Exact fractions in [BigInt] rather than doubles, for the reason `money.dart`
/// gives: `0.1 * 3` must not become a figure that then gets recorded as takings.
/// The answer is rounded to paisa once, at the end, half away from zero.
///
/// `%` works the way a shop calculator does: `200 + 10%` is 220, because the
/// percent is taken of what it is being added to, and a lone `10%` is 0.10.
class Calculator {
  static const String divide = '÷';
  static const String times = '×';
  static const String minus = '−';
  static const String plus = '+';

  static const Set<String> _operators = {divide, times, minus, plus};
  static const int _maxLength = 40;

  String _input = '';

  /// What has been keyed, shown as typed.
  String get expression => _input;

  bool get isEmpty => _input.isEmpty;

  /// The running answer. Zero until there is something that adds up, so an
  /// unfinished `12 +` keeps showing 12 rather than an error.
  Money get result => evaluate(_input) ?? Money.zero;

  void clear() => _input = '';

  void backspace() {
    if (_input.isEmpty) return;
    _input = _input.substring(0, _input.length - 1);
  }

  void digit(String value) {
    if (_input.length >= _maxLength) return;

    final current = _currentNumber;
    // Paisa is as far as money goes.
    if (current.contains('.') && current.split('.').last.length >= 2) return;
    if (_input.endsWith('%')) return;

    // A leading zero would only ever be a typo: 007 is 7.
    if (current == '0') {
      _input = _input.substring(0, _input.length - 1) + value;
      return;
    }
    _input += value;
  }

  void decimalPoint() {
    if (_input.length >= _maxLength || _input.endsWith('%')) return;
    if (_currentNumber.contains('.')) return;
    _input += _currentNumber.isEmpty ? '0.' : '.';
  }

  /// A second operator replaces the first, because that is what pressing one
  /// after another means. A sale cannot start with one, so that press is ignored.
  void operator_(String value) {
    if (_input.isEmpty || !_operators.contains(value)) return;
    if (_input.length >= _maxLength) return;

    if (_operators.contains(_input[_input.length - 1])) {
      _input = _input.substring(0, _input.length - 1) + value;
      return;
    }
    if (_input.endsWith('.')) _input = _input.substring(0, _input.length - 1);
    _input += value;
  }

  void percent() {
    if (_input.isEmpty || _input.endsWith('%')) return;
    if (_operators.contains(_input[_input.length - 1])) return;
    if (_input.endsWith('.')) _input = _input.substring(0, _input.length - 1);
    _input += '%';
  }

  /// Replaces the expression with its answer, so a calculation can carry on.
  void equals() {
    final answer = evaluate(_input);
    if (answer == null) return;
    _input = answer.isZero ? '' : _plain(answer);
  }

  /// `12.50`, `12.5` and `12` as they would be typed, not as they would print.
  static String _plain(Money value) {
    final wire = value.toWire();
    return wire.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String get _currentNumber =>
      RegExp(r'[0-9.]*$').stringMatch(_input) ?? '';

  /// The value of [input], or null when it does not add up to anything yet, such
  /// as a division by zero.
  static Money? evaluate(String input) {
    var text = input;
    if (text.isEmpty) return Money.zero;

    // A trailing operator is a sum still being typed, not a mistake.
    while (text.isNotEmpty &&
        (_operators.contains(text[text.length - 1]) || text.endsWith('.'))) {
      text = text.substring(0, text.length - 1);
    }
    if (text.isEmpty) return Money.zero;

    final tokens = RegExp(r'[0-9.]+%?|[÷×−+]').allMatches(text).map((m) => m[0]!);

    final values = <_Fraction>[];
    final ops = <String>[];

    for (final token in tokens) {
      if (_operators.contains(token)) {
        ops.add(token);
        continue;
      }

      final isPercent = token.endsWith('%');
      final number = _Fraction.parse(isPercent ? token.substring(0, token.length - 1) : token);
      if (number == null) return null;

      if (!isPercent) {
        values.add(number);
        continue;
      }

      final share = number.divideBy(_Fraction(BigInt.from(100), BigInt.one));
      // Added or taken off: a share of everything before it. Otherwise (a lone
      // `10%`, or `200 × 10%`) it is simply that fraction.
      final additive = ops.isNotEmpty && (ops.last == plus || ops.last == minus);
      if (additive) {
        final base = _sum(values, ops.sublist(0, ops.length - 1));
        if (base == null) return null;
        values.add(base.times(share!));
      } else {
        values.add(share!);
      }
    }

    return _sum(values, ops)?.toMoney();
  }

  /// Multiplication and division first, then addition and subtraction.
  static _Fraction? _sum(List<_Fraction> values, List<String> ops) {
    if (values.isEmpty) return _Fraction(BigInt.zero, BigInt.one);

    final terms = <_Fraction>[values.first];
    final signs = <String>[];

    for (var i = 0; i < ops.length && i + 1 < values.length; i++) {
      final op = ops[i];
      final next = values[i + 1];
      if (op == times) {
        terms.last = terms.last.times(next);
      } else if (op == divide) {
        final quotient = terms.last.divideBy(next);
        if (quotient == null) return null;
        terms.last = quotient;
      } else {
        terms.add(next);
        signs.add(op);
      }
    }

    var total = terms.first;
    for (var i = 0; i < signs.length; i++) {
      total = signs[i] == plus ? total.plus(terms[i + 1]) : total.minus(terms[i + 1]);
    }
    return total;
  }
}

class _Fraction {
  _Fraction(this.top, this.bottom);

  final BigInt top;
  final BigInt bottom;

  static _Fraction? parse(String text) {
    final parts = text.split('.');
    if (parts.length > 2) return null;

    final decimals = parts.length == 2 ? parts[1] : '';
    final digits = parts[0] + decimals;
    if (digits.isEmpty) return null;

    return _Fraction(
      BigInt.parse(digits),
      BigInt.from(10).pow(decimals.length),
    );
  }

  _Fraction plus(_Fraction o) =>
      _Fraction(top * o.bottom + o.top * bottom, bottom * o.bottom);
  _Fraction minus(_Fraction o) =>
      _Fraction(top * o.bottom - o.top * bottom, bottom * o.bottom);
  _Fraction times(_Fraction o) => _Fraction(top * o.top, bottom * o.bottom);

  _Fraction? divideBy(_Fraction o) =>
      o.top == BigInt.zero ? null : _Fraction(top * o.bottom, bottom * o.top);

  Money toMoney() {
    final scaled = top * BigInt.from(100);
    var divisor = bottom;
    var dividend = scaled;
    if (divisor.isNegative) {
      divisor = -divisor;
      dividend = -dividend;
    }

    final negative = dividend.isNegative;
    final absolute = dividend.abs();
    var quotient = absolute ~/ divisor;
    if ((absolute % divisor) * BigInt.two >= divisor) quotient += BigInt.one;

    return Money.fromPaisa((negative ? -quotient : quotient).toInt());
  }
}
