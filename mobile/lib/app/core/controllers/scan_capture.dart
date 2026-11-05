import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/enums/document_type.dart';
import '../../data/repositories/attachment_repository.dart';
import '../../routes/app_nav.dart';
import '../widgets/app_sheet.dart';
import '../widgets/app_toast.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/domain/scan_viewer.dart';

/// Photographs the paper, or picks a photo already taken. Null when the
/// shopkeeper backs out at either step.
Future<XFile?> pickScanPhoto({required String paper}) async {
  final context = Get.context;
  if (context == null) return null;

  final source = await AppSheet.options<ImageSource>(
    context: context,
    title: 'Attach $paper scan',
    options: [
      SheetOption(
        value: ImageSource.camera,
        label: 'Take a photo',
        subtitle: 'Photograph the paper $paper now',
        icon: Icons.photo_camera_outlined,
      ),
      const SheetOption(
        value: ImageSource.gallery,
        label: 'Choose from gallery',
        subtitle: 'A photo or scan already on this phone',
        icon: Icons.photo_library_outlined,
      ),
    ],
  );
  if (source == null) return null;

  // Re-encoded as a JPEG at a size that still reads clearly when zoomed, so a
  // 12MP photo does not cost 5MB of storage and upload per bill.
  return ImagePicker().pickImage(
    source: source,
    imageQuality: 80,
    maxWidth: 2400,
    maxHeight: 2400,
  );
}

/// Photos taken on a form whose record does not exist yet.
///
/// An attachment hangs off a record's id and a new record has none until it is
/// saved, so the photos wait here and are filed by [attachTo] after the save.
/// Not a controller of its own: it lives and dies with the form that owns it.
class ScanDraft {
  ScanDraft({required this.paper});

  /// What the photo is of, as the picker sheet words it.
  final String paper;

  final RxList<XFile> photos = <XFile>[].obs;
  final RxBool isAdding = false.obs;

  Future<void> add() async {
    if (isAdding.value) return;

    isAdding.value = true;
    try {
      final picked = await pickScanPhoto(paper: paper);
      if (picked != null) photos.add(picked);
    } catch (e) {
      AppToast.error('Could not attach the scan. $e');
    } finally {
      isAdding.value = false;
    }
  }

  void removeAt(int index) => photos.removeAt(index);

  /// Files every photo against the saved record, and returns how many could not
  /// be. One bad photo does not stop the rest: the record is already saved, and
  /// its detail screen can still take whatever is missing.
  Future<int> attachTo({
    required AttachmentEntityType entityType,
    required String entityId,
    required DocumentType documentType,
  }) async {
    final attachments = Get.find<AttachmentRepository>();
    var failed = 0;

    for (final photo in photos) {
      try {
        await attachments.add(
          entityType: entityType,
          entityId: entityId,
          documentType: documentType,
          sourcePath: photo.path,
          originalFileName: photo.name,
        );
      } on Exception {
        failed++;
      }
    }
    return failed;
  }
}

/// The scans of a record that already exists: loading, adding and removing
/// them. Shared by the detail screens so each words it for its own paper and
/// does the rest the same way.
class RecordScans {
  RecordScans({
    required this.entityType,
    required this.entityId,
    required this.paper,
    required this.record,
  });

  final AttachmentEntityType entityType;
  final String entityId;

  /// What the photo is of: "bill", "receipt".
  final String paper;

  /// What it is filed against: "bill", "payment".
  final String record;

  final RxBool isAttaching = false.obs;

  AttachmentRepository get _attachments => Get.find<AttachmentRepository>();

  Future<List<ScanFile>> load() async => [
    for (final scan in await _attachments.forEntity(entityType, entityId))
      (attachment: scan, file: await AttachmentRepository.fileFor(scan)),
  ];

  Future<void> attach(DocumentType documentType) async {
    if (isAttaching.value) return;

    isAttaching.value = true;
    try {
      final picked = await pickScanPhoto(paper: paper);
      if (picked == null) return;

      await _attachments.add(
        entityType: entityType,
        entityId: entityId,
        documentType: documentType,
        sourcePath: picked.path,
        originalFileName: picked.name,
      );
      AppToast.success('Scan attached to this $record');
    } catch (e) {
      AppToast.error('Could not attach the scan. $e');
    } finally {
      isAttaching.value = false;
    }
  }

  void open(ScanFile scan, {required String title}) => Get.to<void>(
    () => ScanViewer(scan: scan, title: title, onDelete: () => _remove(scan)),
  );

  Future<void> _remove(ScanFile scan) async {
    final confirmed = await ConfirmDialog.show(
      title: 'Remove this scan?',
      message:
          'The photo is deleted from this phone and from the server. The '
          '$record itself is not affected.',
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
}
