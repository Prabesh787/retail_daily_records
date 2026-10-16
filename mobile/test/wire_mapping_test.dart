import 'dart:convert';
import 'dart:typed_data';

import 'package:billrecord/app/core/domain/money.dart';
import 'package:billrecord/app/core/errors/app_exception.dart';
import 'package:billrecord/app/data/enums/payment_status.dart';
import 'package:billrecord/app/data/enums/sale_payment_mode.dart';
import 'package:billrecord/app/data/enums/sale_type.dart';
import 'package:billrecord/app/data/enums/supplier_payment_mode.dart';
import 'package:billrecord/app/data/models/purchase.dart';
import 'package:billrecord/app/data/models/sale.dart';
import 'package:billrecord/app/data/models/sale_item.dart';
import 'package:billrecord/app/data/models/sale_payment.dart';
import 'package:billrecord/app/data/models/supplier.dart';
import 'package:billrecord/app/data/models/supplier_payment.dart';
import 'package:billrecord/app/data/providers/remote/api_client.dart';
import 'package:billrecord/app/data/repositories/supplier_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// The seam between the API and the app.
///
/// Everything the shop sees now arrives as JSON, so this file covers the two
/// directions of that translation and the one thing that happens when it fails.
/// The cases are the ones that are wrong silently: a date that shifts a day, a
/// decimal that becomes a float, a figure the client recomputes instead of
/// reading, an error the user is never told about.
void main() {
  group('reading a record off the wire', () {
    test('a document date is the day it says, not local midnight', () {
      // The failure this guards: `DateTime.parse` reads a bare date as *local*
      // midnight, which in Kathmandu (UTC+05:45) is 18:15 the previous day — so
      // a bill dated the 17th files itself under the 16th.
      final purchase = Purchase.fromJson(const {
        'id': 'p1',
        'fiscalYearId': 'fy1',
        'supplierId': 's1',
        'billNo': '4521',
        'billDate': '2026-08-17',
        'amount': '100000.00',
      });

      expect(
        purchase.billDate,
        DateTime.utc(2026, 8, 17).millisecondsSinceEpoch,
      );
      expect(purchase.billDateBsOrDerived, isNotEmpty);
    });

    test('money arrives as an exact decimal, never a float', () {
      final purchase = Purchase.fromJson(const {
        'id': 'p1',
        'fiscalYearId': 'fy1',
        'supplierId': 's1',
        'billNo': '1',
        'billDate': '2026-08-17',
        // 0.07 is not exactly representable as a double, which is why the API
        // sends fixed-precision strings and this reads them as scaled integers.
        'amount': '1234.07',
      });

      expect(purchase.amount.toWire(), '1234.07');
      expect(purchase.amount.paisa, 123407);
    });

    test('a supplier carries the balance the server derived', () {
      final supplier = Supplier.fromJson(const {
        'id': 's1',
        'name': 'ABC Textiles',
        'openingBalance': '5000.00',
        'isActive': true,
        'balance': {
          'openingBalance': '5000.00',
          'purchaseTotal': '12000.00',
          'clearedTotal': '3000.00',
          'unclearedTotal': '4000.00',
          'outstanding': '10000.00',
          'billCount': 1,
          'paymentCount': 2,
        },
      });

      // Read, not recomputed. One implementation of the sum means the balance
      // card and the ledger under it cannot disagree.
      expect(supplier.balance!.outstanding, Money.fromWire('10000.00'));
      expect(supplier.balance!.paidTotal, Money.fromWire('7000.00'));
      expect(supplier.balance!.hasHistory, isTrue);
    });

    test('a balance that was not asked for stays absent, not zero', () {
      final supplier = Supplier.fromJson(const {'id': 's1', 'name': 'ABC'});

      // "Not loaded" and "settled" are different things, and a screen that
      // confused them would claim a supplier owes nothing.
      expect(supplier.balance, isNull);
    });

    test('a relation the server included becomes a name to show', () {
      final payment = SupplierPayment.fromJson(const {
        'id': 'pay1',
        'fiscalYearId': 'fy1',
        'supplierId': 's1',
        'paymentDate': '2026-08-17',
        'paymentMode': 'CHEQUE',
        'amount': '4000.00',
        'chequeNo': '00123',
        'chequeDate': '2026-08-20',
        'status': 'ISSUED',
        'supplier': {'id': 's1', 'name': 'ABC Textiles'},
        'purchase': {'id': 'p1', 'billNo': '4521'},
      });

      expect(payment.supplierName, 'ABC Textiles');
      expect(payment.purchaseBillNo, '4521');
      expect(payment.status, PaymentStatus.issued);
      expect(payment.isChequeAwaitingClearance, isTrue);
      // An issued cheque still counts against what is owed — the shop has
      // parted with it — while being reported separately as uncleared.
      expect(payment.recognisedAmount, Money.fromWire('4000.00'));
      expect(payment.unclearedAmount, Money.fromWire('4000.00'));
    });

    test('a sale reads its lines and how it was settled', () {
      final sale = Sale.fromJson(const {
        'id': 'sale1',
        'fiscalYearId': 'fy1',
        'saleDate': '2026-08-17',
        'saleType': 'DETAILED',
        'subtotal': '4000.00',
        'discount': '0.00',
        'totalAmount': '4000.00',
        'items': [
          {
            'id': 'i1',
            'description': 'Printed cotton',
            'quantity': '5.000',
            'unit': 'METER',
            'unitPrice': '800.00',
            'discount': '0.00',
          },
        ],
        'payments': [
          {'id': 'sp1', 'paymentMode': 'CASH', 'amount': '2500.00'},
          {'id': 'sp2', 'paymentMode': 'CREDIT', 'amount': '1500.00'},
        ],
      });

      expect(sale.items.single.amount, Money.fromWire('4000.00'));
      // Credit is a promise, not takings. Counting it is how a day's till
      // stops matching the day book.
      expect(sale.settledTotal, Money.fromWire('2500.00'));
      expect(sale.dueTotal, Money.fromWire('1500.00'));
      expect(sale.isFullyPaid, isFalse);
    });
  });

  group('writing a record to the wire', () {
    test('an itemised sale sends its lines and no total', () {
      final sale = Sale(
        id: '',
        fiscalYearId: 'fy1',
        saleDate: DateTime.utc(2026, 8, 17).millisecondsSinceEpoch,
        saleType: SaleType.detailed,
        totalAmount: Money.fromWire('4000.00'),
        items: [
          SaleItem(
            id: '',
            description: 'Printed cotton',
            quantity: Quantity.fromWire('5'),
            unit: 'METER',
            unitPrice: Money.fromWire('800.00'),
          ),
        ],
      );

      final body = sale.toRequestBody();

      // The lines are the truth; the server derives the totals from them. A
      // figure sent alongside them is only a second opinion waiting to be wrong.
      expect(body.containsKey('totalAmount'), isFalse);
      expect(body.containsKey('subtotal'), isFalse);
      expect(body['saleDate'], '2026-08-17');
      expect((body['items'] as List).single, {
        'description': 'Printed cotton',
        'quantity': '5.000',
        'unit': 'METER',
        'unitPrice': '800.00',
        'discount': '0.00',
      });
    });

    test('a summary sale sends the total, because it is the input', () {
      final sale = Sale(
        id: '',
        fiscalYearId: 'fy1',
        saleDate: DateTime.utc(2026, 8, 17).millisecondsSinceEpoch,
        saleType: SaleType.summary,
        totalAmount: Money.fromWire('65500.00'),
        payments: [
          SalePayment(
            id: '',
            paymentMode: SalePaymentMode.cash,
            amount: Money.fromWire('65500.00'),
          ),
        ],
      );

      final body = sale.toRequestBody();

      expect(body['totalAmount'], '65500.00');
      expect((body['payments'] as List).single, {
        'paymentMode': 'CASH',
        'amount': '65500.00',
        'referenceNo': null,
        'chequeNo': null,
        'chequeDate': null,
        'remarks': null,
      });
    });

    test('a cash payment carries no cheque details', () {
      final body = SupplierPayment(
        id: '',
        fiscalYearId: 'fy1',
        supplierId: 's1',
        paymentDate: DateTime.utc(2026, 8, 17).millisecondsSinceEpoch,
        paymentMode: SupplierPaymentMode.cash,
        amount: Money.fromWire('20000.00'),
        // Left over from the form after switching mode. The server refuses
        // cheque details on a cash payment outright, and it is right to.
        chequeNo: '00123',
      ).toRequestBody();

      expect(body['chequeNo'], isNull);
      expect(body['chequeDate'], isNull);
      expect(body['status'], isNull);
    });

    test('a cheque with no date written on it is dated the day it changed hands',
        () {
      final handedOver = DateTime.utc(2026, 8, 17).millisecondsSinceEpoch;

      final body = SupplierPayment(
        id: '',
        fiscalYearId: 'fy1',
        supplierId: 's1',
        paymentDate: handedOver,
        paymentMode: SupplierPaymentMode.cheque,
        amount: Money.fromWire('30000.00'),
        chequeNo: '00123',
      ).toRequestBody();

      // The register plans around this date, and the server requires one, so
      // there is nowhere for a blank to go.
      expect(body['chequeDate'], '2026-08-17');
      expect(body['chequeNo'], '00123');
    });
  });

  group('the ledger a statement draws', () {
    /// The running balance is the one figure still computed on the device, and
    /// the one a supplier reconciles against line by line. It has to start from
    /// what was carried into the window and finish on the closing figure in the
    /// header — if those two disagree, one of them is lying.
    test('runs from the opening balance to the closing one', () {
      final statement = SupplierStatement.fromJson(const {
        'id': 's1',
        'name': 'ABC Textiles',
        'openingBalance': '5000.00',
        'window': {
          'openingAsOf': '5000.00',
          'purchaseTotal': '12000.00',
          'paymentTotal': '4000.00',
          'unclearedTotal': '0.00',
          'closing': '13000.00',
          'billCount': 1,
          'paymentCount': 1,
        },
        'purchases': [
          {
            'id': 'p1',
            'fiscalYearId': 'fy1',
            'supplierId': 's1',
            'billNo': '4521',
            'billDate': '2026-08-17',
            'amount': '12000.00',
          },
        ],
        'payments': [
          {
            'id': 'pay1',
            'fiscalYearId': 'fy1',
            'supplierId': 's1',
            'paymentDate': '2026-08-20',
            'paymentMode': 'CASH',
            'amount': '4000.00',
            'status': 'CLEARED',
          },
        ],
      });

      final lines = statement.lines;

      // Oldest first, each carrying the balance after it.
      expect(lines.map((l) => l.reference), ['Bill 4521', 'Cash']);
      expect(lines.first.balance, Money.fromWire('17000.00'));
      expect(lines.last.balance, statement.window.closing);
    });

    test('a cancelled payment is listed but settles nothing', () {
      final statement = SupplierStatement.fromJson(const {
        'id': 's1',
        'name': 'ABC Textiles',
        'window': {'openingAsOf': '10000.00', 'closing': '10000.00'},
        'purchases': [],
        'payments': [
          {
            'id': 'pay1',
            'fiscalYearId': 'fy1',
            'supplierId': 's1',
            'paymentDate': '2026-08-20',
            'paymentMode': 'CHEQUE',
            'amount': '4000.00',
            'chequeNo': '00123',
            'status': 'CANCELLED',
          },
        ],
      });

      final line = statement.lines.single;

      // It stays on the statement for the audit trail — a bounced cheque is
      // part of the history — with the running balance unmoved beside it.
      expect(line.status, PaymentStatus.cancelled);
      expect(line.credit, Money.zero);
      expect(line.balance, Money.fromWire('10000.00'));
    });
  });

  group('when the server says no', () {
    ApiClient clientReturning(int status, Object body, {void Function()? on401}) =>
        ApiClient(
          baseUrl: 'https://shop.test/api/v1',
          adapter: _FixedResponse(status, body),
          onUnauthorized: on401,
        );

    test('a refusal keeps the message the shopkeeper needs to read', () async {
      final client = clientReturning(409, {
        'success': false,
        'message':
            'Bill number "4521" is already recorded for this supplier in this '
                'fiscal year',
        'code': 'DUPLICATE',
        'errors': [
          {'field': 'body.billNo', 'message': 'Already used this year'},
        ],
      });

      await expectLater(
        client.post('/purchases'),
        throwsA(
          isA<ValidationException>()
              .having((e) => e.message, 'message', contains('4521'))
              // Prefixed by the validator, stripped here, so a form can point
              // at the field that caused it.
              .having((e) => e.errorFor('billNo'), 'field error',
                  'Already used this year'),
        ),
      );
    });

    test('a missing record is distinguishable from a broken one', () async {
      final client = clientReturning(404, {
        'success': false,
        'message': 'Supplier with id s1 was not found',
      });

      await expectLater(
        client.get('/suppliers/s1'),
        throwsA(isA<ValidationException>().having(
          (e) => e.isNotFound,
          'isNotFound',
          isTrue,
        )),
      );
    });

    test('a server fault is a network failure, not a form error', () async {
      final client = clientReturning(500, {'success': false});

      await expectLater(
        client.get('/suppliers'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('a rejected token ends the session once, from wherever it happened',
        () async {
      var ended = 0;
      final client = clientReturning(
        401,
        {'success': false, 'message': 'Token expired'},
        on401: () => ended++,
      );

      await expectLater(client.get('/sales'), throwsA(isA<NetworkException>()));
      expect(ended, 1);
    });

    test('a build with no server address says so instead of failing oddly',
        () async {
      final client = ApiClient(baseUrl: '');

      expect(client.isConfigured, isFalse);
      await expectLater(
        client.get('/sales'),
        throwsA(isA<NetworkException>().having(
          (e) => e.message,
          'message',
          contains('API_BASE_URL'),
        )),
      );
    });
  });
}

/// Answers every request the same way. Enough to exercise the client's own
/// handling without a whole API behind it.
class _FixedResponse implements HttpClientAdapter {
  _FixedResponse(this.status, this.body);

  final int status;
  final Object body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}
