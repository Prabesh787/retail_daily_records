import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/controllers/loader_controller.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/domain/scan_viewer.dart';
import '../../../data/enums/document_type.dart';
import '../../../data/models/purchase.dart';
import '../../../data/models/supplier_payment.dart';
import '../../../data/repositories/attachment_repository.dart';
import '../../../data/repositories/purchase_repository.dart';
import '../../../data/repositories/supplier_payment_repository.dart';
import '../../../routes/app_pages.dart';
import '../../../routes/app_nav.dart';

typedef PurchaseDetail = ({
  Purchase bill,
  List<SupplierPayment> payments,
  List<ScanFile> scans,
});

/// One bill, everything paid against it, and the scan of the paper it came on.
class PurchaseDetailController extends LoaderController<PurchaseDetail> {
  final PurchaseRepository _purchases = Get.find<PurchaseRepository>();
  final SupplierPaymentRepository _payments =
      Get.find<SupplierPaymentRepository>();
  final AttachmentRepository _attachments = Get.find<AttachmentRepository>();

  late final String purchaseId;

  final RxBool isAttaching = false.obs;

  @override
  List<String> get watches => const [
    DbTables.purchase,
    DbTables.supplierPayment,
    DbTables.attachment,
  ];

  Purchase? get bill => data.value?.bill;
  List<SupplierPayment> get payments => data.value?.payments ?? const [];
  List<ScanFile> get scans => data.value?.scans ?? const [];

  @override
  void onInit() {
    final args = Get.arguments;
    purchaseId =
        (args is Map ? args[RouteArgs.purchaseId] as String? : null) ?? '';
    super.onInit();
  }

  @override
  Future<PurchaseDetail> fetch() async {
    final bill = await _purchases.byId(purchaseId);
    if (bill == null) {
      throw const AppException('This bill is no longer in your records.');
    }

    // Fetched separately rather than joined: a bill's payments are a short list
    // read only on this screen, and loading them with every list query would
    // cost every other screen for one.
    final payments = await _payments.list(purchaseId: purchaseId);

    final scans = <ScanFile>[
      for (final scan in await _attachments.forEntity(
        AttachmentEntityType.purchase,
        purchaseId,
      ))
        (attachment: scan, file: await AttachmentRepository.fileFor(scan)),
    ];

    return (bill: bill, payments: payments, scans: scans);
  }

  /// Photographs the paper bill, or picks a photo already taken, and files it
  /// against this purchase.
  Future<void> attachScan() async {
    final context = Get.context;
    if (context == null || isAttaching.value) return;

    final source = await AppSheet.options<ImageSource>(
      context: context,
      title: 'Attach bill scan',
      options: const [
        SheetOption(
          value: ImageSource.camera,
          label: 'Take a photo',
          subtitle: 'Photograph the paper bill now',
          icon: Icons.photo_camera_outlined,
        ),
        SheetOption(
          value: ImageSource.gallery,
          label: 'Choose from gallery',
          subtitle: 'A photo or scan already on this phone',
          icon: Icons.photo_library_outlined,
        ),
      ],
    );
    if (source == null) return;

    isAttaching.value = true;
    try {
      // Re-encoded as a JPEG at a size that still reads clearly when zoomed,
      // so a 12MP photo does not cost 5MB of storage and upload per bill.
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 2400,
        maxHeight: 2400,
      );
      if (picked == null) return;

      await _attachments.add(
        entityType: AttachmentEntityType.purchase,
        entityId: purchaseId,
        documentType: DocumentType.purchaseBill,
        sourcePath: picked.path,
        originalFileName: picked.name,
      );
      AppToast.success('Scan attached to this bill');
    } catch (e) {
      AppToast.error('Could not attach the scan. $e');
    } finally {
      isAttaching.value = false;
    }
  }

  void openScan(ScanFile scan) => Get.to<void>(
    () => ScanViewer(
      scan: scan,
      title: 'Bill ${bill?.billNo ?? ''}'.trim(),
      onDelete: () => removeScan(scan),
    ),
  );

  Future<void> removeScan(ScanFile scan) async {
    final confirmed = await ConfirmDialog.show(
      title: 'Remove this scan?',
      message:
          'The photo is deleted from this phone and from the server. The bill '
          'itself is not affected.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed) return;

    try {
      await _attachments.remove(scan.attachment);
      AppNav.back<void>();
      AppToast.success('Scan removed');
    } catch (e) {
      AppToast.error('Could not remove the scan. $e');
    }
  }

  void openSupplier() {
    final supplierId = bill?.supplierId;
    if (supplierId == null) return;

    Get.toNamed<void>(
      Routes.supplierDetail,
      arguments: {RouteArgs.supplierId: supplierId},
    );
  }

  void openPayment(SupplierPayment payment) => Get.toNamed<void>(
    Routes.paymentDetail,
    arguments: {RouteArgs.paymentId: payment.id},
  );

  /// Opens the payment form already pointed at this bill, so the payment lands
  /// against it rather than floating against the supplier in general.
  void recordPayment() {
    final current = bill;
    if (current == null) return;

    Get.toNamed<void>(
      Routes.paymentForm,
      arguments: {
        RouteArgs.presetSupplierId: current.supplierId,
        RouteArgs.presetPurchaseId: current.id,
      },
    );
  }
}
