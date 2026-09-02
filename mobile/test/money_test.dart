import 'package:billrecord/app/core/domain/money.dart';
import 'package:flutter_test/flutter_test.dart';

/// Money is stored as integer paisa because a supplier's outstanding is derived
/// by summing transactions on the phone *and* on the server, and the two answers
/// have to be the same one. These tests are mostly about the places a floating
/// point type would quietly disagree.
void main() {
  group('reading the wire format', () {
    test('a fixed-precision string becomes exact paisa', () {
      expect(Money.fromWire('100000.00').paisa, 10000000);
      expect(Money.fromWire('0.01').paisa, 1);
      expect(Money.fromWire('-450.25').paisa, -45025);
      expect(Money.fromWire('12.5').paisa, 1250);
      expect(Money.fromWire('9').paisa, 900);
    });

    test('0.07 survives, which it would not as a double', () {
      // 0.07 * 100 == 7.000000000000001 in IEEE 754.
      expect(Money.fromWire('0.07').paisa, 7);
      expect(Money.fromWire('0.29').paisa, 29);
      expect(Money.fromWire('1.15').paisa, 115);
    });

    test('more precision than the column holds rounds half away from zero', () {
      expect(Money.fromWire('0.125').paisa, 13);
      expect(Money.fromWire('0.124').paisa, 12);
      expect(Money.fromWire('-0.125').paisa, -13);
      expect(Money.fromWire('0.005').paisa, 1);
    });

    test('a missing amount is zero rather than a crash', () {
      expect(Money.fromWire(null), Money.zero);
      expect(Money.fromWire(''), Money.zero);
      expect(Money.fromWire('not a number'), Money.zero);
    });

    test('round trips back to the same string', () {
      for (final value in ['0.00', '0.01', '100000.00', '-450.25', '1234560.00']) {
        expect(Money.fromWire(value).toWire(), value);
      }
    });
  });

  group('typed input', () {
    test('commas are tolerated, junk is null', () {
      expect(Money.tryParse('1,00,000')?.paisa, 10000000);
      expect(Money.tryParse('450.5')?.paisa, 45050);
      expect(Money.tryParse('abc'), isNull);
      expect(Money.tryParse(null), isNull);
    });

    test('an empty field is null, not zero', () {
      // "Nothing entered" and "entered zero" are different answers, and a form
      // has to be able to tell them apart.
      expect(Money.tryParse(''), isNull);
      expect(Money.tryParse('0')?.paisa, 0);
    });
  });

  group('arithmetic', () {
    test('adding a tenth ten times is exactly one rupee', () {
      // 0.1 summed ten times as doubles is 0.9999999999999999.
      final tenth = Money.fromWire('0.10');
      expect(Money.sum(List.filled(10, tenth)).toWire(), '1.00');
    });

    test('summing a long ledger does not drift', () {
      final rows = List.generate(1000, (_) => Money.fromWire('0.07'));
      expect(Money.sum(rows).toWire(), '70.00');
    });

    test('subtraction, negation and comparison', () {
      final a = Money.fromWire('100.00');
      final b = Money.fromWire('30.50');
      expect((a - b).toWire(), '69.50');
      expect((b - a).toWire(), '-69.50');
      expect((-b).toWire(), '-30.50');
      expect((b - a).abs.toWire(), '69.50');
      expect(a > b, isTrue);
      expect(a >= Money.fromWire('100.00'), isTrue);
    });

    test('an empty sum is zero', () {
      expect(Money.sum(const []), Money.zero);
    });

    test('value equality, so two reads of a column compare equal', () {
      expect(Money.fromWire('12.34'), Money.fromWire('12.34'));
      expect(Money.fromWire('12.34') == Money.fromWire('12.35'), isFalse);
      expect(Money.fromWire('12.34').hashCode, Money.fromWire('12.34').hashCode);
    });
  });

  group('the SQLite boundary', () {
    test('an INTEGER column round trips', () {
      final amount = Money.fromWire('4521.75');
      expect(Money.fromColumn(amount.toColumn()), amount);
    });

    test('null and a stringified int are both tolerated', () {
      // sqflite can hand back either depending on the driver and the query.
      expect(Money.fromColumn(null), Money.zero);
      expect(Money.fromColumn('45025'), Money.fromWire('450.25'));
    });
  });

  group('quantities', () {
    test('three decimal places, exactly', () {
      expect(Quantity.fromWire('5').milli, 5000);
      expect(Quantity.fromWire('2.345').milli, 2345);
      expect(Quantity.fromWire('0.001').milli, 1);
      expect(Quantity.fromWire('5.000').toWire(), '5.000');
    });

    test('display drops trailing zeros so a line reads "5 METER"', () {
      expect(Quantity.fromWire('5.000').display(), '5');
      expect(Quantity.fromWire('2.500').display(), '2.5');
      expect(Quantity.fromWire('2.345').display(), '2.345');
    });
  });

  group('calculateLineAmount', () {
    /// (quantity, unitPrice, discount, expected).
    ///
    /// Every case here has been run through the real
    /// `backend/src/common/utils/money.js` — Prisma's `Decimal`, not a
    /// reimplementation of it — and all agree. Re-run that check if the
    /// backend's rounding mode ever changes.
    const cases = <(String q, String price, String discount, String amount)>[
      ('2.5', '800.00', '0.00', '2000.00'),
      ('1', '0.01', '0.00', '0.01'),
      ('3', '333.33', '0.00', '999.99'),
      ('0.333', '3.00', '0.00', '1.00'),
      ('1.005', '1.00', '0.00', '1.01'),
      ('2.345', '1.00', '0.00', '2.35'),
      ('7', '142.86', '0.01', '1000.01'),
      ('12.5', '99.99', '50.00', '1199.88'),
      ('0.001', '0.01', '0.00', '0.00'),
      ('1000', '1234.56', '0.00', '1234560.00'),
      ('3.333', '3.33', '1.11', '9.99'),
      ('1.5', '0.05', '0.00', '0.08'),
      ('1.005', '1.00', '3.00', '-2.00'),
    ];

    test('matches the backend on every case', () {
      for (final (q, price, discount, amount) in cases) {
        expect(
          calculateLineAmount(
            Quantity.fromWire(q),
            Money.fromWire(price),
            discount: Money.fromWire(discount),
          ).toWire(),
          amount,
          reason: '$q x $price less $discount',
        );
      }
    });

    test('a discount larger than the line is negative, not clamped', () {
      expect(
        calculateLineAmount(
          Quantity.fromWire('1'),
          Money.fromWire('100.00'),
          discount: Money.fromWire('150.00'),
        ).toWire(),
        '-50.00',
      );
    });

    test('a zero quantity is a zero line', () {
      expect(
        calculateLineAmount(Quantity.zero, Money.fromWire('800.00')),
        Money.zero,
      );
    });
  });

  group('display', () {
    test('groups in lakhs, the way the shop reads it', () {
      expect(Money.fromWire('1234567.00').display(), 'Rs 12,34,567.00');
      expect(Money.fromWire('1000.00').display(), 'Rs 1,000.00');
      expect(Money.fromWire('1234567.00').display(decimals: false), 'Rs 12,34,567');
      expect(Money.fromWire('450.25').display(symbol: ''), '450.25');
    });

    test('short form uses K, L and Cr', () {
      expect(Money.fromWire('45500.00').displayShort(), 'Rs 45.5K');
      expect(Money.fromWire('120000.00').displayShort(), 'Rs 1.20L');
      expect(Money.fromWire('23000000.00').displayShort(), 'Rs 2.30Cr');
      expect(Money.fromWire('750.00').displayShort(), 'Rs 750');
      expect(Money.fromWire('-120000.00').displayShort(), 'Rs -1.20L');
    });
  });
}
