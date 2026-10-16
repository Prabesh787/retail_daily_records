import '../../core/constants/entities.dart';
import '../../core/errors/app_exception.dart';
import '../models/purchase.dart';
import 'base_repository.dart';

class PurchaseRepository extends BaseRepository {
  @override
  String get entity => Entities.purchase;

  /// Bills newest first, each carrying what has been paid against it.
  ///
  /// [onlyUnpaid] is what the payment form offers when the shopkeeper picks the
  /// bill a payment settles: a fully settled bill is not a choice worth showing.
  Future<List<Purchase>> list({
    String? supplierId,
    String? fiscalYearId,
    int? fromMs,
    int? toMs,
    String? search,
    bool onlyUnpaid = false,
    int? limit,
  }) async {
    final response = await api.purchases(
      query: {
        ...window(fromMs: fromMs, toMs: toMs),
        'supplierId': supplierId,
        'fiscalYearId': fiscalYearId,
        'q': search,
        if (onlyUnpaid) 'onlyUnpaid': 'true',
        'limit': pageSize(limit),
      },
    );
    return response.rows.map(Purchase.fromJson).toList();
  }

  Future<Purchase?> byId(String id) async {
    if (id.isEmpty) return null;
    try {
      final response = await api.purchase(id);
      return Purchase.fromJson(response.object);
    } on ValidationException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// Records a wholesale bill.
  ///
  /// The checks here are the ones a form can answer without asking the server —
  /// an empty field, a zero amount. Everything that needs the books to answer
  /// it, a duplicate bill number above all, is the server's to refuse, and its
  /// message is written for a shopkeeper and passed straight through.
  Future<Purchase> save(Purchase purchase) async {
    if (purchase.billNo.trim().isEmpty) {
      throw const ValidationException('A bill needs its number.');
    }
    if (purchase.supplierId.isEmpty) {
      throw const ValidationException('A bill needs a supplier.');
    }
    if (!purchase.amount.isPositive) {
      throw const ValidationException('A bill amount has to be more than zero.');
    }

    final draft = purchase.copyWith(billNo: purchase.billNo.trim());

    return write(() async {
      final response = draft.id.isEmpty
          ? await api.createPurchase(draft.toRequestBody())
          : await api.updatePurchase(draft.id, draft.toRequestBody());
      return Purchase.fromJson(response.object);
    });
  }

  /// Refuses while payments point at the bill — settling a bill that no longer
  /// exists is not a state the ledger can explain.
  Future<void> delete(String id) => write(() => api.deletePurchase(id));
}
