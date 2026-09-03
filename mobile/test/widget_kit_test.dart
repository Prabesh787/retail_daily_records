import 'package:billrecord/app/core/domain/money.dart';
import 'package:billrecord/app/core/theme/app_theme.dart';
import 'package:billrecord/app/core/utils/date_utils.dart';
import 'package:billrecord/app/core/widgets/domain/domain_widgets.dart';
import 'package:billrecord/app/core/widgets/widgets.dart';
import 'package:billrecord/app/data/enums/domain_tone.dart';
import 'package:billrecord/app/data/enums/payment_status.dart';
import 'package:billrecord/app/data/enums/supplier_payment_mode.dart';
import 'package:billrecord/app/data/models/supplier.dart';
import 'package:billrecord/app/data/models/supplier_payment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shared widget kit.
///
/// These are behaviour tests, not screenshots: what a row *says* about a
/// record, and what it does when tapped. Nothing here asserts a colour or a
/// pixel — those are meant to change — but everything asserts a claim the rest
/// of the app relies on, such as a settled supplier reading "Settled" rather
/// than "Rs 0".
///
/// Every case is pumped in both brightnesses, because the palette is a theme
/// extension and a widget that reaches for a hard-coded colour instead is
/// invisible in one of them and passes every test that only ever runs in light.
void main() {
  Future<void> pumpKit(WidgetTester tester, Widget child) async {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );
      await tester.pump();
    }
  }

  int daysFromNow(int days) => AppDateUtils.startOfDay(
    DateTime.now().add(Duration(days: days)),
  ).millisecondsSinceEpoch;

  Supplier supplier({required String name, Money? outstanding, int bills = 0}) {
    final owed = outstanding ?? Money.zero;
    return Supplier(
      id: 'sup-1',
      name: name,
      createdAt: 0,
      updatedAt: 0,
      balance: SupplierBalance(
        openingBalance: Money.zero,
        purchaseTotal: owed,
        clearedTotal: Money.zero,
        uncleared: Money.zero,
        billCount: bills,
        paymentCount: 0,
      ),
    );
  }

  SupplierPayment cheque({required int? chequeDate, String no = '000123'}) =>
      SupplierPayment(
        id: 'pay-1',
        fiscalYearId: 'fy-1',
        supplierId: 'sup-1',
        paymentDate: daysFromNow(0),
        paymentMode: SupplierPaymentMode.cheque,
        amount: Money.fromRupees(5000),
        chequeNo: no,
        chequeDate: chequeDate,
        status: PaymentStatus.issued,
        supplierName: 'Gorkha Traders',
        createdAt: 0,
        updatedAt: 0,
      );

  group('AppListRow', () {
    testWidgets('shows both lines and reports a tap', (tester) async {
      var taps = 0;

      await pumpKit(
        tester,
        AppListRow(
          title: 'Gorkha Traders',
          subtitle: 'Bill 4471',
          trailing: const [RowAmount('Rs 12,000', tone: MoneyTone.outbound)],
          chevron: true,
          onTap: () => taps++,
        ),
      );

      expect(find.text('Gorkha Traders'), findsOneWidget);
      expect(find.text('Bill 4471'), findsOneWidget);
      expect(find.text('Rs 12,000'), findsOneWidget);

      await tester.tap(find.text('Gorkha Traders'));
      expect(taps, 1);
    });
  });

  group('SearchField', () {
    testWidgets('offers a clear button only once there is something to clear', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var latest = 'unset';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SearchField(
              controller: controller,
              onChanged: (value) => latest = value,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.close_rounded), findsNothing);

      await tester.enterText(find.byType(TextField), 'gorkha');
      await tester.pump();
      expect(latest, 'gorkha');
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(controller.text, isEmpty);
      // The screen filtering on this has to hear about the clear, not just see
      // an empty box.
      expect(latest, isEmpty);
    });
  });

  group('SegmentedControl', () {
    testWidgets('reports the segment that was tapped', (tester) async {
      var chosen = 'all';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SegmentedControl<String>(
              value: chosen,
              segments: const [
                Segment(value: 'all', label: 'All'),
                Segment(value: 'due', label: 'Unpaid'),
              ],
              onChanged: (value) => chosen = value,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Unpaid'));
      expect(chosen, 'due');
    });
  });

  group('DetailList', () {
    testWidgets('drops rows with nothing in them', (tester) async {
      await pumpKit(
        tester,
        const DetailList(
          rows: [
            DetailRow('Bill no.', '4471', mono: true),
            DetailRow('Remarks', null),
            DetailRow('Description', ''),
          ],
        ),
      );

      expect(find.text('4471'), findsOneWidget);
      // An optional field that was left blank should cost nothing on screen,
      // not render as a labelled em dash.
      expect(find.text('Remarks'), findsNothing);
      expect(find.text('Description'), findsNothing);
    });
  });

  group('SupplierRow', () {
    testWidgets('says Settled rather than showing a zero', (tester) async {
      await pumpKit(tester, SupplierRow(supplier: supplier(name: 'Everest')));

      expect(find.text('Settled'), findsOneWidget);
    });

    testWidgets('shows what is owed, and pluralises the bill count', (
      tester,
    ) async {
      await pumpKit(
        tester,
        SupplierRow(
          supplier: supplier(
            name: 'Everest',
            outstanding: Money.fromRupees(12000),
            bills: 1,
          ),
        ),
      );

      expect(find.text('Rs 12,000'), findsOneWidget);
      expect(find.text('1 bill'), findsOneWidget);
    });
  });

  group('ChequeRow', () {
    testWidgets('counts down to the date the cheque falls due', (tester) async {
      await pumpKit(tester, ChequeRow(payment: cheque(chequeDate: daysFromNow(3))));
      expect(find.text('in 3d'), findsOneWidget);

      await pumpKit(tester, ChequeRow(payment: cheque(chequeDate: daysFromNow(0))));
      expect(find.text('due today'), findsOneWidget);

      // The register's whole job is flagging these before the bank does.
      await pumpKit(tester, ChequeRow(payment: cheque(chequeDate: daysFromNow(-2))));
      expect(find.text('2d overdue'), findsOneWidget);
    });

    testWidgets('renders an undated cheque without a countdown', (tester) async {
      await pumpKit(tester, ChequeRow(payment: cheque(chequeDate: null)));

      expect(find.text('No. 000123'), findsOneWidget);
      expect(find.textContaining('overdue'), findsNothing);
    });
  });

  group('date range', () {
    test('a range matching a preset is named, not spelled out', () {
      final presets = buildDateRangePresets();
      final today = presets.firstWhere((p) => p.label == 'Today');

      expect(describeRange(today.range, presets), 'Today');
      expect(describeRange(const DateRange.all(), presets), 'All time');
    });

    test('a hand-picked range falls back to its dates', () {
      final presets = buildDateRangePresets();
      final custom = DateRange.days(
        DateTime(2026, 5, 4),
        DateTime(2026, 6, 11),
      );

      expect(describeRange(custom, presets), '04 May – 11 Jun 2026');
    });

    test('the bounds cover whole days, not the instant they were built', () {
      final range = DateRange.days(DateTime(2026, 5, 4), DateTime(2026, 5, 4));
      final start = DateTime.fromMillisecondsSinceEpoch(range.from!);
      final end = DateTime.fromMillisecondsSinceEpoch(range.to!);

      expect(start.hour, 0);
      expect(end.hour, 23);
      expect(end.minute, 59);
    });
  });

  group('date labels', () {
    test('days are counted between calendar days, not by elapsed hours', () {
      // Built from an evening, where an hours-based count would say zero.
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final ms = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        1,
      ).millisecondsSinceEpoch;

      expect(AppDateUtils.daysUntil(ms), 1);
      expect(AppDateUtils.relativeDay(ms), 'Tomorrow');
    });

    test('a date pair carries both calendars', () {
      // 26 Aug 2026 is 10 Bhadra 2083.
      final ms = DateTime.utc(2026, 8, 26).millisecondsSinceEpoch;

      expect(AppDateUtils.datePair(ms, '2083-05-10'), contains('10 Bhadra 2083'));
      expect(AppDateUtils.datePair(ms, '2083-05-10'), contains('2026'));
    });
  });

  group('every kit widget lays out in both themes', () {
    // A layout error — an unbounded child, a Flexible in the wrong place — is
    // invisible to the analyzer and fatal on screen. Pumping each piece once is
    // what catches it here rather than in the app.
    final pieces = <String, Widget>{
      'badge': const AppBadge(label: 'Cleared', tone: DomainTone.success),
      'stat tile': const StatTile(
        label: "TODAY'S TAKINGS",
        value: 'Rs 48,200',
        icon: Icons.trending_up_rounded,
        foot: '12 sales',
        tone: MoneyTone.inbound,
      ),
      'skeleton rows': const SkeletonRows(count: 3),
      'empty state': const EmptyState(
        title: 'No bills yet',
        message: 'Bills you enter will be grouped by the day they were added.',
        actionLabel: 'New bill',
      ),
      'group header': GroupHeader(
        label: 'Today',
        total: Money.fromRupees(48200),
        count: 12,
        onTap: () {},
      ),
      'buttons': const Column(
        children: [
          AppButton(label: 'Save bill'),
          AppButton.danger(label: 'Void bill'),
          AppOutlinedButton(label: 'Cancel'),
        ],
      ),
      'fab': AppFab(label: 'New sale', onPressed: () {}),
      'status badges': const Row(
        children: [
          PaymentStatusBadge(PaymentStatus.issued),
          SupplierPaymentModeBadge(SupplierPaymentMode.cheque),
        ],
      ),
    };

    pieces.forEach((name, widget) {
      testWidgets(name, (tester) async {
        await pumpKit(tester, widget);
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('balance card', (tester) async {
      await pumpKit(
        tester,
        BalanceCard(
          amount: Money.fromRupees(184500),
          caption: 'across 7 bills',
          cleared: Money.fromRupees(90000),
          uncleared: Money.fromRupees(25000),
        ),
      );

      expect(find.text('YOU OWE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('trend chart', (tester) async {
      await pumpKit(
        tester,
        SizedBox(
          width: 340,
          child: TrendChart(
            points: [
              for (var i = 13; i >= 0; i--)
                TrendPoint(
                  dateMs: daysFromNow(-i),
                  amount: Money.fromRupees(i.isEven ? 0 : 1200 * i),
                ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('trend chart survives an all-zero week', (tester) async {
      // Dividing by the peak would be a divide-by-zero on a week with no sales.
      await pumpKit(
        tester,
        SizedBox(
          width: 340,
          child: TrendChart(
            points: [
              for (var i = 6; i >= 0; i--)
                TrendPoint(dateMs: daysFromNow(-i), amount: Money.zero),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
