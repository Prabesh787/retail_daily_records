import 'package:get/get.dart';

import '../../../core/controllers/account_choice.dart';
import '../../../core/domain/calculator.dart';
import '../../../core/domain/money.dart';
import '../../../core/domain/pay_method.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/enums/sale_type.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/sale.dart';
import '../../../data/models/sale_payment.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/fiscal_year_repository.dart';
import '../../../data/repositories/sale_repository.dart';

/// A sale in as few taps as possible: key the amount, tap Record.
///
/// Cash needs nothing else, which is the point. The form stays open afterwards,
/// because a counter takes one sale after another. A cheque is not offered here:
/// its number and date are the opposite of quick, and the full form has them.
class QuickSaleController extends GetxController {
  final SaleRepository _sales = Get.find<SaleRepository>();
  final CustomerRepository _customers = Get.find<CustomerRepository>();
  final FiscalYearRepository _years = Get.find<FiscalYearRepository>();

  static const List<PayMethod> methods = [
    PayMethod.cash,
    PayMethod.bank,
    PayMethod.credit,
  ];

  final Calculator _calculator = Calculator();
  final AccountChoice account = AccountChoice();

  final RxString expression = ''.obs;
  final Rx<Money> total = Money.zero.obs;
  final Rx<PayMethod> method = PayMethod.cash.obs;
  final Rxn<Customer> customer = Rxn<Customer>();
  final RxnString customerError = RxnString();
  final RxBool isSaving = false.obs;

  /// The last sale recorded here, so the shopkeeper can see it landed.
  final Rxn<Money> lastSale = Rxn<Money>();

  void _changed() {
    expression.value = _calculator.expression;
    total.value = _calculator.result;
  }

  void digit(String value) {
    _calculator.digit(value);
    _changed();
  }

  void decimalPoint() {
    _calculator.decimalPoint();
    _changed();
  }

  void operator_(String value) {
    _calculator.operator_(value);
    _changed();
  }

  void percent() {
    _calculator.percent();
    _changed();
  }

  void backspace() {
    _calculator.backspace();
    _changed();
  }

  void clear() {
    _calculator.clear();
    _changed();
  }

  void equals() {
    _calculator.equals();
    _changed();
  }

  void setMethod(PayMethod value) {
    method.value = value;
    if (value.needsAccount) account.preselectOnlyBank();
  }

  void setCustomer(Customer? value) {
    customer.value = value;
    customerError.value = null;
  }

  Future<List<Customer>> searchCustomers(String query) =>
      _customers.list(search: query.isEmpty ? null : query);

  Future<void> record() async {
    if (isSaving.value) return;

    final amount = total.value;
    if (!amount.isPositive) {
      AppToast.error('Enter the amount first.');
      return;
    }
    if (method.value.needsAccount && !account.validate()) return;
    if (method.value.isCredit && customer.value == null) {
      customerError.value = 'A credit sale needs a customer';
      return;
    }

    isSaving.value = true;
    try {
      final today = AppDateUtils.startOfTodayMs();
      final year = await _years.forDate(today);
      if (year == null) {
        throw const ValidationException(
          'No fiscal year covers today. Add one under More first.',
        );
      }

      await _sales.save(
        Sale(
          id: '',
          createdAt: 0,
          updatedAt: 0,
          fiscalYearId: year.id,
          saleDate: today,
          customerId: customer.value?.id,
          saleType: SaleType.summary,
          totalAmount: amount,
          payments: [
            SalePayment(
              id: '',
              saleId: '',
              paymentMode: method.value.saleMode,
              amount: amount,
              accountId: method.value.needsAccount ? account.id : null,
            ),
          ],
        ),
      );

      AppToast.success('${amount.display()} recorded');
      lastSale.value = amount;

      // Ready for the next one. Bank stays chosen for a shop that takes QR all
      // day; a customer belongs to this sale alone.
      clear();
      setCustomer(null);
      if (method.value.isCredit) method.value = PayMethod.cash;
    } on ValidationException catch (e) {
      AppToast.error(e.message);
    } catch (e) {
      AppToast.error('Could not record this sale. $e');
    } finally {
      isSaving.value = false;
    }
  }
}
