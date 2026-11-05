import 'package:get/get.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/controllers/loader_controller.dart';
import '../../../core/controllers/scan_capture.dart';
import '../../../core/widgets/domain/date_range_sheet.dart';
import '../../../core/widgets/domain/scan_viewer.dart';
import '../../../data/enums/document_type.dart';
import '../../../data/models/attachment.dart';
import '../../../data/models/supplier.dart';
import '../../../data/repositories/attachment_repository.dart';
import '../../../data/repositories/supplier_repository.dart';

/// One tile: what the gallery says about a scan, and where its bytes are.
typedef GalleryItem = ({GalleryScan record, ScanFile scan});

/// One supplier's scans.
typedef GalleryGroup = ({
  String supplierId,
  String supplierName,
  List<GalleryItem> items,
});

/// The scans on this phone, split into bills and receipts and grouped by
/// supplier. Cheque copies count as receipts: both are the paper behind a
/// payment. Scans filed against a sale have no supplier and are not shown.
class GalleryController extends LoaderController<List<GalleryGroup>> {
  final AttachmentRepository _attachments = Get.find<AttachmentRepository>();
  final SupplierRepository _suppliers = Get.find<SupplierRepository>();

  final Rx<AttachmentEntityType> kind = AttachmentEntityType.purchase.obs;
  final Rxn<Supplier> supplier = Rxn<Supplier>();
  final Rx<DateRange> range = const DateRange.all().obs;

  /// Suppliers and the parent records are watched as well as scans: renaming a
  /// supplier or deleting a bill changes what this screen shows.
  @override
  List<String> get watches => const [
    DbTables.attachment,
    DbTables.purchase,
    DbTables.supplierPayment,
    DbTables.supplier,
  ];

  List<GalleryGroup> get groups => data.value ?? const [];

  @override
  bool get isEmpty => groups.isEmpty;

  bool get isFiltered => supplier.value != null || !range.value.isAll;

  bool get showingBills => kind.value == AttachmentEntityType.purchase;

  @override
  Future<List<GalleryGroup>> fetch() async {
    final rows = await _attachments.gallery(
      entityType: kind.value,
      supplierId: supplier.value?.id,
      fromMs: range.value.from,
      toMs: range.value.to,
    );

    final files = await Future.wait(
      rows.map((row) => AttachmentRepository.fileFor(row.attachment)),
    );

    final groups = <GalleryGroup>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      // The query orders by supplier, so each one's scans arrive together.
      if (groups.isEmpty || groups.last.supplierId != row.supplierId) {
        groups.add((
          supplierId: row.supplierId,
          supplierName: row.supplierName,
          items: [],
        ));
      }
      groups.last.items.add((
        record: row,
        scan: (attachment: row.attachment, file: files[i]),
      ));
    }
    return groups;
  }

  Future<List<Supplier>> searchSuppliers(String query) =>
      _suppliers.list(search: query);

  void setKind(AttachmentEntityType value) {
    kind.value = value;
    load(silent: true);
  }

  void setSupplier(Supplier value) {
    supplier.value = value;
    load(silent: true);
  }

  void setRange(DateRange value) {
    range.value = value;
    load(silent: true);
  }

  void clearFilters() {
    supplier.value = null;
    range.value = const DateRange.all();
    load(silent: true);
  }

  void open(GalleryItem item) {
    final attachment = item.scan.attachment;
    final isBill = attachment.entityType == AttachmentEntityType.purchase;

    RecordScans(
      entityType: attachment.entityType,
      entityId: attachment.entityId,
      paper: isBill ? 'bill' : 'receipt',
      record: isBill ? 'bill' : 'payment',
    ).open(item.scan, title: item.record.title);
  }
}
