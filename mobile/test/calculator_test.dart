import 'package:billrecord/app/core/domain/calculator.dart';
import 'package:billrecord/app/core/domain/money.dart';
import 'package:flutter_test/flutter_test.dart';

/// Quick Sale records whatever this says, so it is pinned the way money is.
void main() {
  Money eval(String input) => Calculator.evaluate(input)!;

  test('does the arithmetic in the usual order', () {
    expect(eval('2+3×4'), Money.fromRupees(14));
    expect(eval('10−4÷2'), Money.fromRupees(8));
  });

  test('never picks up floating point error', () {
    // 0.1 × 3 is 0.30000000000000004 in a double.
    expect(eval('0.1×3'), Money.fromPaisa(30));
    expect(eval('1.1+2.2'), Money.fromPaisa(330));
  });

  test('rounds to paisa once, half away from zero', () {
    expect(eval('10÷3'), Money.fromPaisa(333));
    expect(eval('2÷3'), Money.fromPaisa(67));
  });

  test('percent works the way a shop calculator does', () {
    expect(eval('200+10%'), Money.fromRupees(220));
    expect(eval('200−10%'), Money.fromRupees(180));
    expect(eval('200×10%'), Money.fromRupees(20));
    expect(eval('10%'), Money.fromPaisa(10));
  });

  test('an unfinished sum shows what it has so far', () {
    expect(eval('12+'), Money.fromRupees(12));
    expect(eval('12.'), Money.fromRupees(12));
  });

  test('division by zero is not an answer', () {
    expect(Calculator.evaluate('5÷0'), isNull);

    final calc = Calculator()
      ..digit('5')
      ..operator_(Calculator.divide)
      ..digit('0');
    expect(calc.result, Money.zero);
  });

  group('keying', () {
    test('a second operator replaces the first', () {
      final calc = Calculator()
        ..digit('5')
        ..operator_(Calculator.plus)
        ..operator_(Calculator.times);
      expect(calc.expression, '5×');
    });

    test('a sale cannot start with an operator', () {
      final calc = Calculator()..operator_(Calculator.plus);
      expect(calc.isEmpty, isTrue);
    });

    test('stops at two decimal places', () {
      final calc = Calculator()
        ..digit('1')
        ..decimalPoint()
        ..digit('2')
        ..digit('5')
        ..digit('9');
      expect(calc.expression, '1.25');
    });

    test('allows only one point in a number', () {
      final calc = Calculator()
        ..digit('1')
        ..decimalPoint()
        ..decimalPoint();
      expect(calc.expression, '1.');
    });

    test('a leading zero is replaced', () {
      final calc = Calculator()
        ..digit('0')
        ..digit('7');
      expect(calc.expression, '7');
    });

    test('equals carries the answer on', () {
      final calc = Calculator()
        ..digit('1')
        ..digit('0')
        ..operator_(Calculator.times)
        ..digit('3')
        ..equals()
        ..operator_(Calculator.plus)
        ..digit('5');
      expect(calc.expression, '30+5');
      expect(calc.result, Money.fromRupees(35));
    });

    test('backspace and clear', () {
      final calc = Calculator()
        ..digit('1')
        ..digit('2')
        ..backspace();
      expect(calc.expression, '1');

      calc.clear();
      expect(calc.isEmpty, isTrue);
      expect(calc.result, Money.zero);
    });
  });
}
