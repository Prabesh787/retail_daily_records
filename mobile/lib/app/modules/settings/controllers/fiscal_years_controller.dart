import 'package:get/get.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/controllers/loader_controller.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/models/fiscal_year.dart';
import '../../../data/repositories/fiscal_year_repository.dart';

/// The years every record is filed under.
///
/// Small screen, load-bearing rule: exactly one year is active, and it is the
/// one new records are filed against. Every form in the app refuses to save a
/// record whose date falls outside any year, so this is where that gets fixed.
class FiscalYearsController extends LoaderController<List<FiscalYear>> {
  final FiscalYearRepository _years = Get.find<FiscalYearRepository>();

  final RxBool isSaving = false.obs;

  @override
  List<String> get watches => const [DbTables.fiscalYear];

  List<FiscalYear> get rows => data.value ?? const [];

  @override
  bool get isEmpty => rows.isEmpty;

  @override
  Future<List<FiscalYear>> fetch() => _years.list();

  /// Whether any year covers today. When nothing does, every form in the app
  /// will refuse to save — so the screen says so rather than letting the user
  /// discover it one rejected bill at a time.
  bool get coversToday => rows.any((y) => y.isCurrent);

  Future<void> activate(FiscalYear year) async {
    if (year.isActive) return;

    final confirmed = await ConfirmDialog.show(
      title: 'Make ${year.name} the active year?',
      message: 'New bills, sales and payments will be filed under it. Records '
          'already entered stay where they are.',
      confirmLabel: 'Activate',
    );
    if (!confirmed) return;

    try {
      await _years.activate(year.id);
      AppToast.success('${year.name} is now active');
    } catch (e) {
      AppToast.error('Could not activate that year. $e');
    }
  }

  Future<void> remove(FiscalYear year) async {
    final confirmed = await ConfirmDialog.show(
      title: 'Delete ${year.name}?',
      message: 'Only possible while nothing is filed under it.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;

    try {
      await _years.delete(year.id);
      AppToast.success('${year.name} deleted');
    } on ValidationException catch (e) {
      AppToast.error(e.message);
    }
  }

  /// Saves a year collected by the sheet.
  ///
  /// The sheet itself lives in the view: a controller that builds widgets is a
  /// controller that cannot be tested without pumping one.
  Future<void> create(FiscalYear draft) async {
    if (isSaving.value) return;

    isSaving.value = true;
    try {
      await _years.save(draft);
      AppToast.success('${draft.name} added');
    } on ValidationException catch (e) {
      AppToast.error(e.message);
    } catch (e) {
      AppToast.error('Could not save that year. $e');
    } finally {
      isSaving.value = false;
    }
  }
}
