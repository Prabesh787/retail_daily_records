import 'dart:convert';
import 'dart:typed_data';

import 'package:billrecord/app/core/domain/money.dart';
import 'package:billrecord/app/core/utils/date_utils.dart';
import 'package:billrecord/app/core/utils/nepali_date.dart';
import 'package:dio/dio.dart';

/// The Express API, in memory.
///
/// A screen test needs data behind it, and the two easy ways to provide that
/// are both worse than this one. Stubbing the repositories tests the stubs;
/// stubbing one canned response per endpoint tests nothing about how the
/// screens relate — a supplier's balance would agree with the bills only
/// because someone typed both numbers.
///
/// So this is a small real implementation, plugged in as Dio's transport, which
/// means every layer above it is the shipping one: the client's envelope
/// unwrapping, the error mapping, the models' parsing, the repositories. What
/// it derives, it derives the way the server does — balances from the bills and
/// payments, sale totals from the lines — so a test that seeds a bill and then
/// reads a supplier is exercising the same relationship the real system has.
///
/// It is not a specification of the API. `backend/` is. This mirrors the shapes
/// closely enough that a screen cannot tell the difference, and where the two
/// drift the screen tests are what notice.
class FakeBackend implements HttpClientAdapter {
  FakeBackend({this.prefix = '/api/v1'});

  /// The path the API is mounted under, stripped before routing.
  final String prefix;

  final List<Map<String, dynamic>> fiscalYears = [];
  final List<Map<String, dynamic>> suppliers = [];
  final List<Map<String, dynamic>> customers = [];
  final List<Map<String, dynamic>> purchases = [];
  final List<Map<String, dynamic>> payments = [];
  final List<Map<String, dynamic>> sales = [];

  /// Every request that has been made, for a test that wants to assert the app
  /// asked for the right thing rather than only that it drew the answer.
  final List<String> requests = [];

  int _ids = 0;

  /// Uuid-shaped, because the API's `:id` routes validate the shape and a test
  /// that passes `s1` around would not catch a client building a bad path.
  String newId() {
    final n = (++_ids).toRadixString(16).padLeft(12, '0');
    return '00000000-0000-4000-8000-$n';
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path.replaceFirst(prefix, '');
    final method = options.method.toUpperCase();
    final query = options.uri.queryParameters;
    final body = options.data is Map<String, dynamic>
        ? options.data as Map<String, dynamic>
        : const <String, dynamic>{};

    requests.add('$method $path');

    try {
      return _ok(_route(method, path, query, body));
    } on _ApiRefusal catch (e) {
      return _fail(e.status, e.message);
    }
  }

  @override
  void close({bool force = false}) {}

  // ---- Routing ------------------------------------------------------------

  Object? _route(
    String method,
    String path,
    Map<String, String> query,
    Map<String, dynamic> body,
  ) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    final head = segments.isEmpty ? '' : segments.first;
    final id = segments.length > 1 ? segments[1] : null;
    final action = segments.length > 2 ? segments[2] : null;

    return switch (head) {
      'health' => {'status': 'ok'},
      'auth' => _auth(method, id, body),
      'fiscal-years' => _fiscalYears(method, id, action, body),
      'suppliers' => _suppliers(method, id, query, body),
      'customers' => _customers(method, id, query, body),
      'purchases' => _purchases(method, id, query, body),
      'supplier-payments' => _payments(method, id, action, query, body),
      'sales' => _sales(method, id, query, body),
      'reports' => _reports(id, query),
      _ => throw _ApiRefusal(404, 'No route for $path'),
    };
  }

  // ---- Auth ---------------------------------------------------------------

  Map<String, dynamic> account = {
    'id': '00000000-0000-4000-8000-00000000000a',
    'name': 'Shopkeeper',
    'email': 'admin@retails-records.local',
    'role': 'ADMIN',
    'isActive': true,
    'shop': {
      'name': 'Test Shop',
      'address': 'Butwal-11',
      'phone': '9800000000',
      'pan': '123456789',
    },
  };

  Object? _auth(String method, String? id, Map<String, dynamic> body) {
    if (id == 'login') return {...account, 'token': 'test-token'};
    if (id != 'me') throw _ApiRefusal(404, 'No such auth route');

    if (method == 'PATCH') {
      account = {
        ...account,
        if (body['name'] != null) 'name': body['name'],
        'shop': {
          'name': body['shopName'],
          'address': body['shopAddress'],
          'phone': body['shopPhone'],
          'pan': body['shopPan'],
        },
      };
    }
    return account;
  }

  // ---- Fiscal years -------------------------------------------------------

  Object? _fiscalYears(
    String method,
    String? id,
    String? action,
    Map<String, dynamic> body,
  ) {
    if (method == 'GET' && id == null) return fiscalYears;

    if (method == 'GET' && id == 'active') {
      final active = fiscalYears.where((y) => y['isActive'] == true);
      if (active.isEmpty) throw _ApiRefusal(404, 'No active fiscal year');
      return active.first;
    }

    if (method == 'POST' && id == null) {
      if (fiscalYears.any((y) => y['name'] == body['name'])) {
        throw _ApiRefusal(409, '"${body['name']}" already exists');
      }
      final year = {'id': newId(), ...body, ..._stamps()};
      fiscalYears.add(year);
      if (year['isActive'] == true) _activateOnly(year['id'] as String);
      return year;
    }

    final year = _find(fiscalYears, id, 'Fiscal year');

    if (method == 'POST' && action == 'activate') {
      _activateOnly(id!);
      return year;
    }
    if (method == 'PATCH') {
      year.addAll(body);
      if (year['isActive'] == true) _activateOnly(id!);
      return year;
    }
    if (method == 'DELETE') {
      final filed = [...purchases, ...payments, ...sales]
          .any((row) => row['fiscalYearId'] == id);
      if (filed) {
        throw _ApiRefusal(
          422,
          '${year['name']} has records filed under it and cannot be removed.',
        );
      }
      fiscalYears.remove(year);
      return null;
    }

    return year;
  }

  void _activateOnly(String id) {
    for (final year in fiscalYears) {
      year['isActive'] = year['id'] == id;
    }
  }

  // ---- Suppliers ----------------------------------------------------------

  Object? _suppliers(
    String method,
    String? id,
    Map<String, String> query,
    Map<String, dynamic> body,
  ) {
    if (method == 'POST') {
      final supplier = {
        'id': newId(),
        'isActive': true,
        ...body,
        'openingBalance': _money(body['openingBalance']),
        ..._stamps(),
      };
      suppliers.add(supplier);
      return _withBalance(supplier);
    }

    if (method == 'GET' && id == null) {
      final term = (query['q'] ?? query['search'] ?? '').toLowerCase();
      final rows = suppliers
          .where(
            (s) =>
                term.isEmpty ||
                ['name', 'phone', 'contactPerson'].any(
                  (key) =>
                      (s[key]?.toString().toLowerCase() ?? '').contains(term),
                ),
          )
          .where(
            (s) =>
                query['isActive'] == null ||
                (s['isActive'] == true) == (query['isActive'] == 'true'),
          )
          .map(_withBalance)
          .toList()
        ..sort(
          (a, b) => _m(b['balance']['outstanding'])
              .compareTo(_m(a['balance']['outstanding'])),
        );
      return rows;
    }

    final supplier = _find(suppliers, id, 'Supplier');

    if (method == 'PATCH') {
      supplier.addAll({
        ...body,
        if (body.containsKey('openingBalance'))
          'openingBalance': _money(body['openingBalance']),
      });
      return _withBalance(supplier);
    }

    if (method == 'DELETE') {
      final history = [...purchases, ...payments]
          .any((row) => row['supplierId'] == id);
      if (history) {
        throw _ApiRefusal(
          422,
          'This supplier has transaction record(s) and cannot be deleted. '
          'Deactivate it instead.',
        );
      }
      suppliers.remove(supplier);
      return null;
    }

    // The detail read: the party, its position, and the ledger for a window.
    final from = _dayOf(query['from']);
    final to = _dayOf(query['to']);
    final term = (query['q'] ?? query['search'] ?? '').toLowerCase();

    final bills = purchases
        .where((p) => p['supplierId'] == id)
        .where((p) => _inWindow(_dayOf(p['billDate']), from, to))
        .where((p) => term.isEmpty || _matches(p, term, ['billNo', 'description']))
        .toList()
      ..sort((a, b) => _dayOf(b['billDate'])!.compareTo(_dayOf(a['billDate'])!));

    final paid = payments
        .where((p) => p['supplierId'] == id)
        .where((p) => _inWindow(_dayOf(p['paymentDate']), from, to))
        .where(
          (p) => term.isEmpty ||
              _matches(p, term, ['voucherNo', 'chequeNo', 'referenceNo']),
        )
        .map(_withPurchase)
        .toList()
      ..sort(
        (a, b) => _dayOf(b['paymentDate'])!.compareTo(_dayOf(a['paymentDate'])!),
      );

    return {
      ..._withBalance(supplier),
      'window': _window(supplier, from, to),
      'purchases': bills,
      'payments': paid,
    };
  }

  /// The one calculation the system is built around:
  ///
  ///     outstanding = opening + purchases − payments that are not cancelled
  ///
  /// Derived here, never stored, exactly as on the server.
  Map<String, dynamic> _withBalance(Map<String, dynamic> supplier) {
    final id = supplier['id'];
    final bills = purchases.where((p) => p['supplierId'] == id).toList();
    final settled = payments
        .where((p) => p['supplierId'] == id && p['status'] != 'CANCELLED')
        .toList();

    final opening = _m(supplier['openingBalance']);
    final purchaseTotal = Money.sum(bills.map((p) => _m(p['amount'])));
    final cleared = Money.sum(
      settled.where((p) => p['status'] == 'CLEARED').map((p) => _m(p['amount'])),
    );
    final uncleared = Money.sum(
      settled.where((p) => p['status'] == 'ISSUED').map((p) => _m(p['amount'])),
    );

    return {
      ...supplier,
      'balance': {
        'openingBalance': opening.toWire(),
        'purchaseTotal': purchaseTotal.toWire(),
        'paidTotal': (cleared + uncleared).toWire(),
        'clearedTotal': cleared.toWire(),
        'unclearedTotal': uncleared.toWire(),
        'outstanding':
            (opening + purchaseTotal - cleared - uncleared).toWire(),
        'billCount': bills.length,
        'paymentCount': settled.length,
      },
    };
  }

  /// The same arithmetic narrowed to a window — a statement rather than a
  /// position. `openingAsOf` is what was carried into `from`, which is what
  /// lets the closing figure reconcile with the balance above it.
  Map<String, dynamic> _window(
    Map<String, dynamic> supplier,
    int? from,
    int? to,
  ) {
    final id = supplier['id'];

    Money priorSum(List<Map<String, dynamic>> rows, String dateKey) => from == null
        ? Money.zero
        : Money.sum(
            rows
                .where((r) => _dayOf(r[dateKey])! < from)
                .map((r) => _m(r['amount'])),
          );

    final bills = purchases.where((p) => p['supplierId'] == id).toList();
    final settled = payments
        .where((p) => p['supplierId'] == id && p['status'] != 'CANCELLED')
        .toList();

    final openingAsOf = _m(supplier['openingBalance']) +
        priorSum(bills, 'billDate') -
        priorSum(settled, 'paymentDate');

    final windowBills =
        bills.where((p) => _inWindow(_dayOf(p['billDate']), from, to)).toList();
    final windowPaid = settled
        .where((p) => _inWindow(_dayOf(p['paymentDate']), from, to))
        .toList();

    final purchaseTotal = Money.sum(windowBills.map((p) => _m(p['amount'])));
    final cleared = Money.sum(
      windowPaid
          .where((p) => p['status'] == 'CLEARED')
          .map((p) => _m(p['amount'])),
    );
    final uncleared = Money.sum(
      windowPaid
          .where((p) => p['status'] == 'ISSUED')
          .map((p) => _m(p['amount'])),
    );
    final paymentTotal = cleared + uncleared;

    return {
      'from': from == null ? null : _iso(from),
      'to': to == null ? null : _iso(to),
      'openingAsOf': openingAsOf.toWire(),
      'purchaseTotal': purchaseTotal.toWire(),
      'paymentTotal': paymentTotal.toWire(),
      'clearedTotal': cleared.toWire(),
      'unclearedTotal': uncleared.toWire(),
      'closing': (openingAsOf + purchaseTotal - paymentTotal).toWire(),
      'billCount': windowBills.length,
      'paymentCount': windowPaid.length,
    };
  }

  // ---- Customers ----------------------------------------------------------

  Object? _customers(
    String method,
    String? id,
    Map<String, String> query,
    Map<String, dynamic> body,
  ) {
    if (method == 'POST') {
      final customer = {'id': newId(), ...body, ..._stamps()};
      customers.add(customer);
      return _withSaleTotals(customer);
    }

    if (method == 'GET' && id == null) {
      final term = (query['q'] ?? query['search'] ?? '').toLowerCase();
      return customers
          .where(
            (c) =>
                term.isEmpty || _matches(c, term, ['name', 'phone', 'address']),
          )
          .map(_withSaleTotals)
          .toList();
    }

    final customer = _find(customers, id, 'Customer');

    if (method == 'PATCH') {
      customer.addAll(body);
      return _withSaleTotals(customer);
    }
    if (method == 'DELETE') {
      if (sales.any((s) => s['customerId'] == id)) {
        throw _ApiRefusal(
          422,
          '${customer['name']} has invoices recorded and cannot be removed.',
        );
      }
      customers.remove(customer);
      return null;
    }
    return _withSaleTotals(customer);
  }

  Map<String, dynamic> _withSaleTotals(Map<String, dynamic> customer) {
    final theirs = sales.where((s) => s['customerId'] == customer['id']);
    return {
      ...customer,
      'saleCount': theirs.length,
      'saleTotal': Money.sum(theirs.map((s) => _m(s['totalAmount']))).toWire(),
    };
  }

  // ---- Purchases ----------------------------------------------------------

  Object? _purchases(
    String method,
    String? id,
    Map<String, String> query,
    Map<String, dynamic> body,
  ) {
    if (method == 'POST') {
      final duplicate = purchases.any(
        (p) =>
            p['supplierId'] == body['supplierId'] &&
            p['fiscalYearId'] == body['fiscalYearId'] &&
            p['billNo'] == body['billNo'],
      );
      if (duplicate) {
        throw _ApiRefusal(
          409,
          'Bill number "${body['billNo']}" is already recorded for this '
          'supplier in this fiscal year',
        );
      }

      final purchase = {
        'id': newId(),
        ...body,
        'amount': _money(body['amount']),
        'billDateBs': body['billDateBs'] ?? _bs(body['billDate']),
        ..._stamps(),
      };
      purchases.add(purchase);
      return _purchaseRow(purchase);
    }

    if (method == 'GET' && id == null) {
      final from = _dayOf(query['from']);
      final to = _dayOf(query['to']);
      final term = (query['q'] ?? query['search'] ?? '').toLowerCase();

      return purchases
          .where(
            (p) =>
                query['supplierId'] == null ||
                p['supplierId'] == query['supplierId'],
          )
          .where((p) => _inWindow(_dayOf(p['billDate']), from, to))
          .where(
            (p) => term.isEmpty || _matches(p, term, ['billNo', 'description']),
          )
          .map(_purchaseRow)
          .where(
            (p) =>
                query['onlyUnpaid'] != 'true' || _m(p['dueTotal']).isPositive,
          )
          .toList()
        ..sort(
          (a, b) => _dayOf(b['billDate'])!.compareTo(_dayOf(a['billDate'])!),
        );
    }

    final purchase = _find(purchases, id, 'Purchase');

    if (method == 'DELETE') {
      if (payments.any((p) => p['purchaseId'] == id)) {
        throw _ApiRefusal(
          422,
          'This bill has payment(s) recorded against it and cannot be deleted.',
        );
      }
      purchases.remove(purchase);
      return null;
    }
    if (method == 'PATCH') {
      purchase.addAll(body);
      return _purchaseRow(purchase);
    }

    return {
      ..._purchaseRow(purchase),
      'payments': payments.where((p) => p['purchaseId'] == id).toList(),
      'attachments': const [],
    };
  }

  /// A bill with what has been settled against it. Cancelled payments settled
  /// nothing, so they do not count.
  Map<String, dynamic> _purchaseRow(Map<String, dynamic> purchase) {
    final against = payments.where(
      (p) => p['purchaseId'] == purchase['id'] && p['status'] != 'CANCELLED',
    );
    final paid = Money.sum(against.map((p) => _m(p['amount'])));

    return {
      ...purchase,
      'supplier': _relation(suppliers, purchase['supplierId']),
      'paidTotal': paid.toWire(),
      'dueTotal': (_m(purchase['amount']) - paid).toWire(),
    };
  }

  // ---- Supplier payments --------------------------------------------------

  Object? _payments(
    String method,
    String? id,
    String? action,
    Map<String, String> query,
    Map<String, dynamic> body,
  ) {
    if (method == 'POST' && id == null) {
      // Cash is money already gone; a cheque is a promise until the bank pays
      // it. That difference is the default, and the reason for the register.
      final isCheque = body['paymentMode'] == 'CHEQUE';
      final status = body['status'] ?? (isCheque ? 'ISSUED' : 'CLEARED');

      final payment = {
        'id': newId(),
        ...body,
        'amount': _money(body['amount']),
        'status': status,
        'clearedDate': status == 'CLEARED' ? body['paymentDate'] : null,
        'paymentDateBs': body['paymentDateBs'] ?? _bs(body['paymentDate']),
        ..._stamps(),
      };
      payments.add(payment);
      return _withPurchase(payment);
    }

    if (method == 'GET' && id == null) {
      return _paymentList(query).toList();
    }

    // Cheques in the order the money has to be in the bank: by the date on the
    // cheque, not the day it was handed over.
    if (method == 'GET' && id == 'cheque-register') {
      return _paymentList(query, dateKey: 'chequeDate')
          .where((p) => p['paymentMode'] == 'CHEQUE')
          .toList()
        ..sort(
          (a, b) => (_dayOf(a['chequeDate']) ?? _dayOf(a['paymentDate'])!)
              .compareTo(_dayOf(b['chequeDate']) ?? _dayOf(b['paymentDate'])!),
        );
    }

    final payment = _find(payments, id, 'Supplier payment');

    if (method == 'POST' && action == 'clear') {
      if (payment['status'] == 'CANCELLED') {
        throw _ApiRefusal(422, 'A cancelled payment cannot be cleared.');
      }
      payment['status'] = 'CLEARED';
      payment['clearedDate'] = body['clearedDate'];
      return _withPurchase(payment);
    }
    if (method == 'POST' && action == 'cancel') {
      payment['status'] = 'CANCELLED';
      payment['clearedDate'] = null;
      return _withPurchase(payment);
    }
    if (method == 'DELETE') {
      payments.remove(payment);
      return null;
    }

    return _withPurchase(payment);
  }

  Iterable<Map<String, dynamic>> _paymentList(
    Map<String, String> query, {
    String dateKey = 'paymentDate',
  }) {
    final from = _dayOf(query['from']);
    final to = _dayOf(query['to']);
    final term = (query['q'] ?? query['search'] ?? '').toLowerCase();

    return payments
        .where(
          (p) =>
              query['supplierId'] == null ||
              p['supplierId'] == query['supplierId'],
        )
        .where(
          (p) =>
              query['purchaseId'] == null ||
              p['purchaseId'] == query['purchaseId'],
        )
        .where((p) => query['status'] == null || p['status'] == query['status'])
        .where((p) => _inWindow(_dayOf(p[dateKey]), from, to))
        .where(
          (p) => term.isEmpty ||
              _matches(p, term, ['voucherNo', 'chequeNo', 'referenceNo']),
        )
        .map(_withPurchase);
  }

  Map<String, dynamic> _withPurchase(Map<String, dynamic> payment) {
    final bill = payment['purchaseId'] == null
        ? null
        : purchases.cast<Map<String, dynamic>?>().firstWhere(
              (p) => p!['id'] == payment['purchaseId'],
              orElse: () => null,
            );

    return {
      ...payment,
      'supplier': _relation(suppliers, payment['supplierId']),
      if (bill != null)
        'purchase': {
          'id': bill['id'],
          'billNo': bill['billNo'],
          'billDate': bill['billDate'],
          'amount': bill['amount'],
        },
    };
  }

  // ---- Sales --------------------------------------------------------------

  Object? _sales(
    String method,
    String? id,
    Map<String, String> query,
    Map<String, dynamic> body,
  ) {
    if (method == 'POST') {
      // Totals are derived here, never accepted: the lines are the truth for a
      // detailed sale, and the figure typed is the truth for a summary one.
      final items = (body['items'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(
            (item) => {
              'id': newId(),
              ...item,
              'amount': calculateLineAmount(
                Quantity.fromWire(item['quantity']),
                Money.fromWire(item['unitPrice']),
                discount: Money.fromWire(item['discount']),
              ).toWire(),
            },
          )
          .toList();

      final discount = _m(body['discount']);
      final detailed = body['saleType'] == 'DETAILED';
      final subtotal = detailed
          ? Money.sum(items.map((i) => _m(i['amount'])))
          : _m(body['totalAmount']) + discount;
      final total = subtotal - discount;

      final sale = {
        'id': newId(),
        ...body,
        'saleDateBs': body['saleDateBs'] ?? _bs(body['saleDate']),
        'subtotal': subtotal.toWire(),
        'discount': discount.toWire(),
        'totalAmount': total.toWire(),
        'items': items,
        'payments': (body['payments'] as List? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(
              (p) => {
                'id': newId(),
                ...p,
                'amount': _money(p['amount']),
                'status': p['status'] ??
                    (p['paymentMode'] == 'CREDIT' ? 'ISSUED' : 'CLEARED'),
              },
            )
            .toList(),
        ..._stamps(),
      };
      sales.add(sale);
      return _saleRow(sale, withItems: true);
    }

    if (method == 'GET' && id == 'day-book') return _dayBook(query['date']);

    if (method == 'GET' && id == null) {
      final from = _dayOf(query['from']);
      final to = _dayOf(query['to']);
      final term = (query['q'] ?? query['search'] ?? '').toLowerCase();

      return sales
          .where(
            (s) =>
                query['saleType'] == null || s['saleType'] == query['saleType'],
          )
          .where(
            (s) =>
                query['customerId'] == null ||
                s['customerId'] == query['customerId'],
          )
          .where((s) => _inWindow(_dayOf(s['saleDate']), from, to))
          .where(
            (s) =>
                term.isEmpty || _matches(s, term, ['invoiceNo', 'description']),
          )
          .map((s) => _saleRow(s))
          .toList()
        ..sort(
          (a, b) => _dayOf(b['saleDate'])!.compareTo(_dayOf(a['saleDate'])!),
        );
    }

    final sale = _find(sales, id, 'Sale');
    if (method == 'DELETE') {
      sales.remove(sale);
      return null;
    }
    return _saleRow(sale, withItems: true);
  }

  /// A list row carries its settlement lines but not its invoice lines: "sold"
  /// and "taken" are different figures a list has to keep apart, while the
  /// lines are data no list draws.
  Map<String, dynamic> _saleRow(
    Map<String, dynamic> sale, {
    bool withItems = false,
  }) =>
      {
        ...sale,
        if (!withItems) 'items': const [],
        'customer': _relation(customers, sale['customerId']),
      };

  /// Everything recorded on one date, across all three ledgers.
  Map<String, dynamic> _dayBook(String? date) {
    final day = _dayOf(date) ?? AppDateUtils.todayMs();
    final iso = _iso(day);

    final theDay = sales
        .where((s) => _dayOf(s['saleDate']) == day)
        .map((s) => _saleRow(s, withItems: true))
        .toList();
    final bills = purchases
        .where((p) => _dayOf(p['billDate']) == day)
        .map(_purchaseRow)
        .toList();
    final paid = payments
        .where((p) => _dayOf(p['paymentDate']) == day)
        .map(_withPurchase)
        .toList();

    return {
      'date': iso,
      'dateBs': NepaliDate.msToBs(day),
      'sales': theDay,
      'purchases': bills,
      'payments': paid,
      'totals': {
        'sales': Money.sum(theDay.map((s) => _m(s['totalAmount']))).toWire(),
        'saleCount': theDay.length,
        'purchases': Money.sum(bills.map((p) => _m(p['amount']))).toWire(),
        'purchaseCount': bills.length,
        'payments': Money.sum(
          paid
              .where((p) => p['status'] != 'CANCELLED')
              .map((p) => _m(p['amount'])),
        ).toWire(),
        'paymentCount':
            paid.where((p) => p['status'] != 'CANCELLED').length,
      },
    };
  }

  // ---- Reports ------------------------------------------------------------

  Object? _reports(String? name, Map<String, String> query) => switch (name) {
        'dashboard' => _dashboard(int.tryParse(query['trendDays'] ?? '') ?? 14),
        'supplier-outstanding' => _supplierOutstanding(),
        _ => throw _ApiRefusal(404, 'No such report'),
      };

  Map<String, dynamic> _dashboard(int trendDays) {
    final today = AppDateUtils.todayMs();
    final owing = _outstandingSuppliers();

    final todaysSales = sales.where((s) => _dayOf(s['saleDate']) == today);
    final received = Money.sum(
      todaysSales.expand(
        (s) => (s['payments'] as List).cast<Map<String, dynamic>>().where(
              (p) => p['paymentMode'] != 'CREDIT' && p['status'] != 'CANCELLED',
            ),
      ).map((p) => _m(p['amount'])),
    );

    final cheques = payments
        .where((p) => p['paymentMode'] == 'CHEQUE' && p['status'] == 'ISSUED')
        .map(_withPurchase)
        .toList()
      ..sort(
        (a, b) => (_dayOf(a['chequeDate']) ?? _dayOf(a['paymentDate'])!)
            .compareTo(_dayOf(b['chequeDate']) ?? _dayOf(b['paymentDate'])!),
      );

    List<Map<String, dynamic>> newestFirst(
      List<Map<String, dynamic>> rows,
      String dateKey,
    ) =>
        [...rows]..sort(
            (a, b) => _dayOf(b[dateKey])!.compareTo(_dayOf(a[dateKey])!),
          );

    return {
      'today': {
        'date': _iso(today),
        'dateBs': NepaliDate.msToBs(today),
        'salesTotal':
            Money.sum(todaysSales.map((s) => _m(s['totalAmount']))).toWire(),
        'salesCount': todaysSales.length,
        'receivedTotal': received.toWire(),
      },
      'payable': {
        'total': Money.sum(
          owing.map((s) => _m(s['balance']['outstanding'])),
        ).toWire(),
        'supplierCount': owing.length,
        'top': owing
            .take(4)
            .map((s) => {'supplier': s, 'balance': s['balance']})
            .toList(),
      },
      'cheques': {
        'count': cheques.length,
        'total': Money.sum(cheques.map((p) => _m(p['amount']))).toWire(),
        'next': cheques.take(3).toList(),
      },
      // Zeros included: the quiet days are the information, so the report fills
      // them in rather than leaving gaps for a chart to skip.
      'trend': [
        for (var i = trendDays - 1; i >= 0; i--)
          () {
            final day = today - Duration(days: i).inMilliseconds;
            final onDay = sales.where((s) => _dayOf(s['saleDate']) == day);
            return {
              'date': _iso(day),
              'dateBs': NepaliDate.msToBs(day),
              'amount':
                  Money.sum(onDay.map((s) => _m(s['totalAmount']))).toWire(),
              'count': onDay.length,
            };
          }(),
      ],
      'recentSales':
          newestFirst(sales, 'saleDate').take(4).map((s) => _saleRow(s)).toList(),
      'recentPurchases':
          newestFirst(purchases, 'billDate').take(4).map(_purchaseRow).toList(),
      'fiscalYear': fiscalYears.where((y) => y['isActive'] == true).firstOrNull,
    };
  }

  List<Map<String, dynamic>> _outstandingSuppliers() =>
      suppliers.map(_withBalance).where((s) {
        return _m(s['balance']['outstanding']).isPositive;
      }).toList()
        ..sort(
          (a, b) => _m(b['balance']['outstanding'])
              .compareTo(_m(a['balance']['outstanding'])),
        );

  Map<String, dynamic> _supplierOutstanding() {
    final rows = _outstandingSuppliers();
    return {
      'asOf': {
        'date': _iso(AppDateUtils.todayMs()),
        'dateBs': NepaliDate.msToBs(AppDateUtils.todayMs()),
      },
      'totals': {
        'outstanding':
            Money.sum(rows.map((s) => _m(s['balance']['outstanding']))).toWire(),
        'uncleared': Money.sum(
          rows.map((s) => _m(s['balance']['unclearedTotal'])),
        ).toWire(),
        'supplierCount': suppliers.length,
        'owingCount': rows.length,
      },
      'suppliers': rows,
    };
  }

  // ---- Plumbing -----------------------------------------------------------

  Map<String, dynamic> _find(
    List<Map<String, dynamic>> rows,
    String? id,
    String name,
  ) {
    for (final row in rows) {
      if (row['id'] == id) return row;
    }
    throw _ApiRefusal(404, '$name with id $id was not found');
  }

  Map<String, dynamic>? _relation(List<Map<String, dynamic>> rows, Object? id) {
    if (id == null) return null;
    for (final row in rows) {
      if (row['id'] == id) return {'id': row['id'], 'name': row['name']};
    }
    return null;
  }

  bool _matches(Map<String, dynamic> row, String term, List<String> keys) =>
      keys.any(
        (key) => (row[key]?.toString().toLowerCase() ?? '').contains(term),
      );

  bool _inWindow(int? day, int? from, int? to) {
    if (day == null) return from == null && to == null;
    if (from != null && day < from) return false;
    if (to != null && day > to) return false;
    return true;
  }

  Money _m(Object? value) => Money.fromWire(value);

  /// Money leaves the API as a fixed-precision string, never a number.
  String _money(Object? value) => Money.fromWire(value).toWire();

  int? _dayOf(Object? iso) =>
      NepaliDate.parseIsoDate(iso?.toString())?.millisecondsSinceEpoch;

  String _iso(int ms) => NepaliDate.toIsoDate(NepaliDate.fromMs(ms));

  String? _bs(Object? iso) => NepaliDate.adIsoToBs(iso?.toString());

  Map<String, dynamic> _stamps() {
    final now = DateTime.now().toUtc().toIso8601String();
    return {'createdAt': now, 'updatedAt': now};
  }

  ResponseBody _ok(Object? data) => _body(200, {
        'success': true,
        'message': 'ok',
        'data': data,
      });

  ResponseBody _fail(int status, String message) => _body(status, {
        'success': false,
        'message': message,
        'code': 'TEST_REFUSAL',
        'errors': const [],
      });

  ResponseBody _body(int status, Map<String, dynamic> payload) =>
      ResponseBody.fromString(
        jsonEncode(payload),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
}

/// The server saying no, in the envelope it says it in.
class _ApiRefusal implements Exception {
  _ApiRefusal(this.status, this.message);

  final int status;
  final String message;
}
