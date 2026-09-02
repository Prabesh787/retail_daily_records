import 'package:billrecord/app/core/utils/nepali_date.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/nepali_date_golden.dart';

/// The phone converts BS dates offline; the server converts them for reports.
/// If the two tables ever disagree, a bill filed on 2083-05-10 in the shop shows
/// up on a different day in the server's day book — and nobody would notice
/// until the month did not add up.
///
/// So the contract under test is not "our conversion is correct" but "our
/// conversion is *the one the backend runs*". The golden fixture is generated
/// from `nepali-date.js` itself.
void main() {
  group('agreement with the backend', () {
    test('AD to BS matches on every golden pair', () {
      for (final (ad, bs) in nepaliDateGolden) {
        expect(NepaliDate.adIsoToBs(ad), bs, reason: 'AD $ad should be BS $bs');
      }
    });

    test('BS to AD matches on every golden pair', () {
      for (final (ad, bs) in nepaliDateGolden) {
        expect(NepaliDate.bsToAdIso(bs), ad, reason: 'BS $bs should be AD $ad');
      }
    });

    test('the fixture spans the range it claims to', () {
      expect(nepaliDateGolden.length, greaterThan(900));
      expect(nepaliDateGolden.first.$1, '1943-04-14');
      expect(nepaliDateGolden.first.$2, '2000-01-01');
    });
  });

  group('the anchor', () {
    test('1 Baishakh 2000 BS is 14 April 1943 AD', () {
      expect(NepaliDate.adIsoToBs('1943-04-14'), '2000-01-01');
      expect(NepaliDate.bsToAdIso('2000-01-01'), '1943-04-14');
    });

    test('the day before the anchor is out of range, not a wrong answer', () {
      expect(NepaliDate.adIsoToBs('1943-04-13'), isNull);
    });
  });

  group('round trips', () {
    test('every day of a BS year converts back to itself', () {
      for (var month = 1; month <= 12; month += 1) {
        final days = NepaliDate.daysInBsMonth(2083, month)!;
        for (var day = 1; day <= days; day += 1) {
          final bs = '2083-${month.toString().padLeft(2, '0')}-'
              '${day.toString().padLeft(2, '0')}';
          expect(NepaliDate.adToBs(NepaliDate.bsToAd(bs)), bs);
        }
      }
    });

    test('epoch millis survive the trip through BS and back', () {
      final ms = NepaliDate.toMs(DateTime.utc(2026, 9, 2));
      expect(NepaliDate.bsToMs(NepaliDate.msToBs(ms)), ms);
    });
  });

  group('rejecting what is not a date', () {
    test('an impossible AD date is null rather than rolled forward', () {
      // DateTime.utc(2026, 2, 31) would silently become 3 March.
      expect(NepaliDate.parseIsoDate('2026-02-31'), isNull);
      expect(NepaliDate.adIsoToBs('2026-02-31'), isNull);
    });

    test('a BS day past the end of its month is null', () {
      final days = NepaliDate.daysInBsMonth(2083, 1)!;
      expect(NepaliDate.bsToAd('2083-01-${days + 1}'), isNull);
    });

    test('out-of-range BS years are null', () {
      expect(NepaliDate.bsToAd('1999-01-01'), isNull);
      expect(NepaliDate.bsToAd('2101-01-01'), isNull);
    });

    test('junk is null, not an exception', () {
      for (final value in [null, '', 'today', '2083', '2083-13-01', '2083-00-05']) {
        expect(NepaliDate.bsToAd(value), isNull, reason: 'bsToAd($value)');
      }
      expect(NepaliDate.adIsoToBs('not a date'), isNull);
    });
  });

  group('the table itself', () {
    test('2096 is the only malformed year, and it is a known defect', () {
      // BS 2096 sums to 364 days in the backend's table and in most published
      // BS libraries. It is inherited on purpose so the phone and the server
      // agree. This test catches a *new* bad row joining it, and fails loudly
      // if someone fixes one side without the other.
      expect(NepaliDate.malformedYears(), [2096]);
    });

    test('covers BS 2000-2100 with twelve months each', () {
      expect(NepaliDate.bsMonthDays.length, 101);
      for (final entry in NepaliDate.bsMonthDays.entries) {
        expect(entry.value.length, 12, reason: 'BS ${entry.key}');
      }
    });
  });

  group('display', () {
    test('formats a BS date the way the shop says it', () {
      expect(NepaliDate.format('2083-05-10'), '10 Bhadra 2083');
      expect(NepaliDate.format('2083-05-10', short: true), '10 Bha');
    });

    test('an unparseable stored string is shown as-is, not lost', () {
      expect(
        NepaliDate.format('whatever the paperwork said'),
        'whatever the paperwork said',
      );
      expect(NepaliDate.format(null), '');
    });

    test('today and yesterday are named rather than dated', () {
      const day = 86400000;
      final today = NepaliDate.todayMs();
      expect(NepaliDate.relativeDay(today), 'Today');
      expect(NepaliDate.relativeDay(today - day), 'Yesterday');
      expect(NepaliDate.relativeDay(today - 5 * day), isNot('Today'));
    });
  });
}
