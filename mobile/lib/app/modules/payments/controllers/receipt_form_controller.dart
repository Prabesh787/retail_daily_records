import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/controllers/account_choice.dart';
import '../../../core/domain/money.dart';
import '../../../core/domain/pay_method.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/nepali_date.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/customer_payment.dart';
import '../../../data/models/sale.dart';
import '../../../data/repositories/customer_payment_repository.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/fiscal_year_repository.dart';
import '../../../data/repositories/sale_repository.dart';
import '../../../routes/app_pages.dart';

/// Payment In: money received from a customer after the sale.
class ReceiptFormController extends GetxController {
  final CustomerPaymentRepository _payments =
      Get.find<CustomerPaymentRepository>();
  final CustomerRepository _customers = Get.find<CustomerRepository>();
  final SaleRepository _sales = Get.find<SaleRepository>();
  final FiscalYearRepository _years = Get.find<FiscalYearRepository>();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController amount = TextEditingController();
  final TextEditingController voucherNo = TextEditingController();
  final TextEditingController chequeNo = TextEditingController();
  final TextEditingController referenceNo = TextEditingController();
  final TextEditingController remarks = TextEditingController();

  final Rxn<Customer> customer = Rxn<Customer>();
  final RxnString customerError = RxnString();
  final Rxn<Sale> againstSale = Rxn<Sale>();
  final Rx<PayMethod> method = PayMethod.cash.obs;
  final AccountChoice account = AccountChoice();
  final RxInt paymentDate = AppDateUtils.startOfTodayMs().obs;
  final RxInt chequeDate = AppDateUtils.startOfTodayMs().obs;
  final RxBool isSaving = false.obs;
  final RxInt amountRevision = 0.obs;

  bool get isCheque => method.value.isCheque;
  bool get hasReference => method.value.needsAccount;

  Money get typedAmount => Money.tryParse(amount.text) ?? Money.zero;

  @override
  void onInit() {
    super.onInit();

    final args = Get.arguments;
    if (args is! Map) return;

    final customerId = args[RouteArgs.presetCustomerId];
    if (customerId is String) _preselectCustomer(customerId);

    final saleId = args[RouteArgs.presetSaleId];
    if (saleId is String) _preselectSale(saleId);
  }

  Future<void> _preselectCustomer(String id) async {
    customer.value = await _customers.byId(id);

    // Receiving from someone usually means settling what they owe, so the
    // amount starts there. It stays editable; part payments are ordinary.
    final owed = customer.value?.receivable;
    if (owed != null && owed.isPositive && amount.text.trim().isEmpty) {
      _setAmount(owed);
    }
  }

  Future<void> _preselectSale(String id) async {
    final sale = await _sales.byId(id);
    againstSale.value = sale;
    if (sale != null && sale.dueTotal.isPositive) _setAmount(sale.dueTotal);
  }

  void _setAmount(Money value) {
    amount.text = value.toWire();
    amountRevision.value++;
  }

  void setDate(int ms) {
    paymentDate.value = ms;
    if (chequeDate.value < ms) chequeDate.value = ms;
  }

  void setChequeDate(int ms) => chequeDate.value = ms;

  void setMethod(PayMethod value) {
    method.value = value;
    if (value.needsAccount) account.preselectOnlyBank();
  }

  void setCustomer(Customer value) {
    customer.value = value;
    customerError.value = null;
    if (againstSale.value?.customerId != value.id) againstSale.value = null;
  }

  Future<List<Customer>> searchCustomers(String query) =>
      _customers.list(search: query.isEmpty ? null : query);

  Future<void> save() async {
    final formValid = formKey.currentState?.validate() ?? false;

    if (customer.value == null) customerError.value = 'Choose the customer';
    final accountValid = !method.value.needsAccount || account.validate();
    if (!formValid || customer.value == null || !accountValid) return;
    if (isSaving.value) return;

    isSaving.value = true;
    try {
      final year = await _years.forDate(paymentDate.value);
      if (year == null) {
        throw const ValidationException(
          'No fiscal year covers that date. Add one under More first.',
        );
      }

      final saved = await _payments.save(
        CustomerPayment(
          id: '',
          createdAt: 0,
          updatedAt: 0,
          fiscalYearId: year.id,
          customerId: customer.value!.id,
          saleId: againstSale.value?.id,
          voucherNo: _trimmed(voucherNo),
          paymentDate: paymentDate.value,
          paymentDateBs: NepaliDate.msToBs(paymentDate.value),
          paymentMode: method.value.paymentMode,
          amount: typedAmount,
          // A cheque reaches a bank only when it clears, so none is asked yet.
          accountId: method.value.needsAccount ? account.id : null,
          chequeNo: isCheque ? _trimmed(chequeNo) : null,
          chequeDate: isCheque ? chequeDate.value : null,
          referenceNo: hasReference ? _trimmed(referenceNo) : null,
          remarks: _trimmed(remarks),
        ),
      );

      AppToast.success(
        isCheque
            ? 'Cheque ${saved.chequeNo} recorded'
            : '${saved.amount.display()} received',
      );
      Get.offNamed<void>(
        Routes.receiptDetail,
        arguments: {RouteArgs.paymentId: saved.id},
      );
    } on ValidationException catch (e) {
      AppToast.error(e.message);
    } catch (e) {
      AppToast.error('Could not save this payment. $e');
    } finally {
      isSaving.value = false;
    }
  }

  String? _trimmed(TextEditingController field) {
    final value = field.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  void onClose() {
    for (final field in [amount, voucherNo, chequeNo, referenceNo, remarks]) {
      field.dispose();
    }
    super.onClose();
  }
}
