import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/domain/money.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/nepali_date.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/enums/sale_payment_mode.dart';
import '../../../data/enums/sale_type.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/sale.dart';
import '../../../data/models/sale_item.dart';
import '../../../data/models/sale_payment.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/fiscal_year_repository.dart';
import '../../../data/repositories/sale_repository.dart';
import '../../../routes/app_pages.dart';

/// One line being typed on the itemised form.
///
/// A draft rather than a [SaleItem] because the fields are half-typed most of
/// the time: "12." is not a quantity yet, and forcing it through the model on
/// every keystroke would either throw or silently round.
class ItemDraft {
  ItemDraft();

  final TextEditingController description = TextEditingController();
  final TextEditingController quantity = TextEditingController(text: '1');
  final TextEditingController unitPrice = TextEditingController();
  final TextEditingController unit = TextEditingController(text: 'pcs');

  Quantity get qty => Quantity.tryParse(quantity.text) ?? Quantity.zero;
  Money get price => Money.tryParse(unitPrice.text) ?? Money.zero;

  /// What this line comes to, through the same `calculateLineAmount` the model
  /// and the backend use — so a line previewed on the form and the same line
  /// read back after saving cannot round differently.
  ///
  /// Recomputed on every read; a stored line total is
  /// a second source of truth waiting to disagree with the two numbers above.
  Money get amount => calculateLineAmount(qty, price);

  bool get isBlank =>
      description.text.trim().isEmpty && unitPrice.text.trim().isEmpty;

  bool get isValid => description.text.trim().isNotEmpty && amount.isPositive;

  SaleItem toItem() => SaleItem(
    id: '',
    saleId: '',
    createdAt: 0,
    description: description.text.trim(),
    quantity: qty,
    unit: unit.text.trim().isEmpty ? 'pcs' : unit.text.trim(),
    unitPrice: price,
  );

  void dispose() {
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
    unit.dispose();
  }
}

/// Recording a sale.
///
/// Two shapes behind one screen. Most shops key a day's counter sales as a
/// single total; an invoice for a bulk customer needs lines. The difference is
/// [SaleType], and switching between them changes what the total *means*: typed
/// in one, derived in the other.
class SaleFormController extends GetxController {
  final SaleRepository _sales = Get.find<SaleRepository>();
  final CustomerRepository _customers = Get.find<CustomerRepository>();
  final FiscalYearRepository _years = Get.find<FiscalYearRepository>();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController invoiceNo = TextEditingController();
  final TextEditingController summaryTotal = TextEditingController();
  final TextEditingController discount = TextEditingController();
  final TextEditingController description = TextEditingController();
  final TextEditingController remarks = TextEditingController();
  final TextEditingController saleDateBs = TextEditingController();
  final TextEditingController paidAmount = TextEditingController();

  final Rx<SaleType> saleType = SaleType.summary.obs;
  final Rx<SalePaymentMode> paymentMode = SalePaymentMode.cash.obs;
  final Rxn<Customer> customer = Rxn<Customer>();
  final RxInt saleDate = AppDateUtils.startOfTodayMs().obs;
  final RxBool isSaving = false.obs;

  /// The itemised lines. Starts with one empty row so the form opens ready to
  /// type rather than opening with an "Add line" button and nothing else.
  final RxList<ItemDraft> items = <ItemDraft>[ItemDraft()].obs;

  /// Bumped whenever a line's text changes, so the totals below the list
  /// recompute. The drafts hold plain controllers, which Obx cannot observe.
  final RxInt itemsRevision = 0.obs;

  final RxnString customerError = RxnString();

  bool _bsEdited = false;

  bool get isItemised => saleType.value.hasItems;
  bool get isCredit => paymentMode.value == SalePaymentMode.credit;

  @override
  void onInit() {
    super.onInit();

    _syncBsFromDate();
    saleDateBs.addListener(() {
      if (saleDateBs.text != _derivedBs) _bsEdited = true;
    });

    _watch(items.first);

    final args = Get.arguments;
    if (args is Map && args[RouteArgs.presetCustomerId] is String) {
      _preselectCustomer(args[RouteArgs.presetCustomerId] as String);
    }
  }

  String get _derivedBs => NepaliDate.msToBs(saleDate.value) ?? '';

  void _syncBsFromDate() {
    if (_bsEdited) return;
    saleDateBs.text = _derivedBs;
  }

  void _watch(ItemDraft draft) {
    void bump() => itemsRevision.value++;
    draft.quantity.addListener(bump);
    draft.unitPrice.addListener(bump);
    draft.description.addListener(bump);
  }

  Future<void> _preselectCustomer(String customerId) async {
    customer.value = await _customers.byId(customerId);
  }

  // --- Totals --------------------------------------------------------------

  /// The lines added up. Only complete lines count, so a half-typed row at the
  /// bottom does not make the total flicker while it is being filled in.
  Money get itemsSubtotal =>
      Money.sum(items.where((d) => d.isValid).map((d) => d.amount));

  Money get discountAmount => Money.tryParse(discount.text) ?? Money.zero;

  /// What the customer owes.
  ///
  /// Derived from the lines when itemised and typed when not — the one place
  /// the two shapes actually differ. The repository recomputes this from the
  /// lines on save regardless, so an itemised total can never be overridden by
  /// whatever is sitting in a text field.
  Money get grandTotal {
    final base = isItemised
        ? itemsSubtotal
        : (Money.tryParse(summaryTotal.text) ?? Money.zero);

    final net = base - discountAmount;
    return net.isNegative ? Money.zero : net;
  }

  /// What is being settled now. Credit settles nothing by definition, so the
  /// field is not asked for in that case.
  Money get paidNow {
    if (isCredit) return Money.zero;

    final typed = Money.tryParse(paidAmount.text);
    // Empty means "paid in full", which is what the overwhelming majority of
    // counter sales are. Making the shopkeeper retype the total to say so
    // would be a keystroke tax on the common case.
    return typed ?? grandTotal;
  }

  Money get dueNow {
    final due = grandTotal - paidNow;
    return due.isNegative ? Money.zero : due;
  }

  // --- Lines ---------------------------------------------------------------

  void addItem() {
    final draft = ItemDraft();
    _watch(draft);
    items.add(draft);
  }

  void removeItem(int index) {
    if (items.length <= 1) return;

    items.removeAt(index).dispose();
    itemsRevision.value++;
  }

  void setSaleType(SaleType value) {
    saleType.value = value;
    itemsRevision.value++;
  }

  void setPaymentMode(SalePaymentMode value) {
    paymentMode.value = value;
    itemsRevision.value++;
  }

  void setDate(int ms) {
    saleDate.value = ms;
    _syncBsFromDate();
  }

  void setCustomer(Customer? value) {
    customer.value = value;
    customerError.value = null;
  }

  Future<List<Customer>> searchCustomers(String query) => _customers.list(
    search: query.isEmpty ? null : query,
  );

  // --- Save ----------------------------------------------------------------

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (isSaving.value) return;

    // A credit sale with nobody to chase is not a record, it is a hole. Every
    // other mode is a counter sale where the customer is genuinely optional.
    if (isCredit && customer.value == null) {
      customerError.value = 'A credit sale needs a customer to chase';
      return;
    }

    final lines = items.where((d) => d.isValid).toList();
    if (isItemised && lines.isEmpty) {
      AppToast.error('Add at least one line, with a description and a price.');
      return;
    }
    if (!grandTotal.isPositive) {
      AppToast.error('The sale total has to be more than zero.');
      return;
    }

    isSaving.value = true;
    try {
      final year = await _years.forDate(saleDate.value);
      if (year == null) {
        throw const ValidationException(
          'No fiscal year covers that date. Add one under More first.',
        );
      }

      final saved = await _sales.save(
        Sale(
          id: '',
          createdAt: 0,
          updatedAt: 0,
          fiscalYearId: year.id,
          invoiceNo: _trimmed(invoiceNo),
          saleDate: saleDate.value,
          saleDateBs: _trimmed(saleDateBs),
          customerId: customer.value?.id,
          saleType: saleType.value,
          description: _trimmed(description),
          discount: discountAmount,
          // Ignored for an itemised sale — the repository recomputes it from
          // the lines — and authoritative for a summary one.
          totalAmount: grandTotal,
          remarks: _trimmed(remarks),
          items: isItemised
              ? [for (final draft in lines) draft.toItem()]
              : const [],
          payments: _payments(),
        ),
      );

      AppToast.success(
        saved.dueTotal.isPositive
            ? 'Sale recorded · ${saved.dueTotal.display()} on credit'
            : 'Sale recorded',
      );
      Get.offNamed<void>(
        Routes.saleDetail,
        arguments: {RouteArgs.saleId: saved.id},
      );
    } on ValidationException catch (e) {
      AppToast.error(e.message);
    } catch (e) {
      AppToast.error('Could not save this sale. $e');
    } finally {
      isSaving.value = false;
    }
  }

  /// How the sale was settled, as payment lines.
  ///
  /// A credit sale gets one CREDIT line for the whole amount rather than no
  /// line at all: "sold on credit" is a fact about the sale, and recording it
  /// as an absence would make it indistinguishable from a sale nobody has got
  /// round to settling yet.
  List<SalePayment> _payments() {
    if (isCredit) {
      return [
        SalePayment(
          id: '',
          saleId: '',
          createdAt: 0,
          paymentMode: SalePaymentMode.credit,
          amount: grandTotal,
        ),
      ];
    }

    return [
      if (paidNow.isPositive)
        SalePayment(
          id: '',
          saleId: '',
          createdAt: 0,
          paymentMode: paymentMode.value,
          amount: paidNow,
        ),
      // A part-paid counter sale: the rest is credit, and saying so here keeps
      // the payment lines adding up to the sale total.
      if (dueNow.isPositive)
        SalePayment(
          id: '',
          saleId: '',
          createdAt: 0,
          paymentMode: SalePaymentMode.credit,
          amount: dueNow,
        ),
    ];
  }

  String? _trimmed(TextEditingController field) {
    final value = field.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  void onClose() {
    for (final draft in items) {
      draft.dispose();
    }
    for (final field in [
      invoiceNo,
      summaryTotal,
      discount,
      description,
      remarks,
      saleDateBs,
      paidAmount,
    ]) {
      field.dispose();
    }
    super.onClose();
  }
}
