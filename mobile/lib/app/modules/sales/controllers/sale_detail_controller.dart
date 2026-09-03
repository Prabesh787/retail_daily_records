import 'package:get/get.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/controllers/loader_controller.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/models/sale.dart';
import '../../../data/repositories/sale_repository.dart';
import '../../../routes/app_pages.dart';

/// One sale: its lines, how it was settled, and what is still owed on it.
class SaleDetailController extends LoaderController<Sale> {
  final SaleRepository _sales = Get.find<SaleRepository>();

  late final String saleId;

  @override
  List<String> get watches => const [DbTables.sale];

  Sale? get sale => data.value;

  @override
  void onInit() {
    final args = Get.arguments;
    saleId = (args is Map ? args[RouteArgs.saleId] as String? : null) ?? '';
    super.onInit();
  }

  @override
  Future<Sale> fetch() async {
    final result = await _sales.byId(saleId);
    if (result == null) {
      throw const AppException('This sale is no longer in your records.');
    }
    return result;
  }

  void openDay() {
    final current = sale;
    if (current == null) return;

    Get.toNamed<void>(
      Routes.saleDay,
      arguments: {RouteArgs.dateMs: current.saleDate},
    );
  }

  /// Deleting a sale is a real deletion of a record of money, so it asks
  /// plainly and says what it means for the day it belonged to.
  Future<void> delete() async {
    final current = sale;
    if (current == null) return;

    final confirmed = await ConfirmDialog.show(
      title: 'Delete this sale?',
      message: '${current.totalAmount.display()} comes off that day’s takings. '
          'There is no separate day total to correct afterwards — the day is '
          'the sum of the sales under it.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;

    try {
      await _sales.delete(saleId);
      AppToast.success('Sale deleted');
      Get.back<void>();
    } catch (e) {
      AppToast.error('Could not delete this sale. $e');
    }
  }
}
