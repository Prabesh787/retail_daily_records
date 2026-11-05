import 'dart:io';

import 'package:billrecord/app/core/constants/db_constants.dart';
import 'package:billrecord/app/core/controllers/scan_capture.dart';
import 'package:billrecord/app/core/domain/money.dart';
import 'package:billrecord/app/core/errors/app_exception.dart';
import 'package:billrecord/app/data/enums/document_type.dart';
import 'package:billrecord/app/data/enums/supplier_payment_mode.dart';
import 'package:billrecord/app/data/enums/sync_status.dart';
import 'package:billrecord/app/data/models/attachment.dart';
import 'package:billrecord/app/data/models/purchase.dart';
import 'package:billrecord/app/data/models/supplier.dart';
import 'package:billrecord/app/data/models/supplier_payment.dart';
import 'package:billrecord/app/data/providers/local/attachment_dao.dart';
import 'package:billrecord/app/data/providers/remote/attachment_api.dart';
import 'package:billrecord/app/data/repositories/attachment_repository.dart';
import 'package:billrecord/app/data/sync/attachment_uploader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'helpers/test_app.dart';

/// A bill scan lives on the device first and reaches the server only once its
/// bill has. These pin both halves: what adding and removing does locally, and
/// what the uploader sends - and refuses to send - afterwards.
void main() {
  late TestApp app;
  late AttachmentRepository repo;
  late AttachmentDao dao;
  late Directory sources;

  const int now = 1700000000000;

  Future<void> insertPurchase(String id, SyncStatus status) => app.db.insert(
    DbTables.purchase,
    Purchase(
      id: id,
      createdAt: now,
      updatedAt: now,
      fiscalYearId: 'fy',
      supplierId: 'sup',
      billNo: id,
      billDate: now,
      amount: Money.fromWire('1000.00'),
      syncStatus: status,
    ).toMap(),
  );

  Future<String> sourcePhoto(String name) async {
    final file = File(p.join(sources.path, name));
    await file.writeAsBytes(List.filled(2048, 7));
    return file.path;
  }

  Future<Attachment> attach(
    String purchaseId, {
    String name = 'bill.jpg',
  }) async => repo.add(
    entityType: AttachmentEntityType.purchase,
    entityId: purchaseId,
    documentType: DocumentType.purchaseBill,
    sourcePath: await sourcePhoto(name),
  );

  setUp(() async {
    app = await TestApp.start();
    repo = AttachmentRepository();
    dao = AttachmentDao(app.db);
    sources = await Directory.systemTemp.createTemp('scan_sources');
  });

  tearDown(() async {
    await app.dispose();
    if (sources.existsSync()) sources.deleteSync(recursive: true);
  });

  group('on the device', () {
    test('adding copies the file in and records it against the bill', () async {
      await insertPurchase('bill-1', SyncStatus.pending);
      final scan = await attach('bill-1');

      final copy = await AttachmentRepository.fileFor(scan);
      expect(copy.existsSync(), isTrue);
      expect(copy.lengthSync(), 2048);
      expect(scan.mimeType, 'image/jpeg');
      expect(scan.originalFileName, 'bill.jpg');

      // The source going away - a cleared temp file, a deleted gallery photo -
      // must not take the scan with it.
      Directory(sources.path).deleteSync(recursive: true);
      expect(copy.existsSync(), isTrue);

      final listed = await repo.forEntity(
        AttachmentEntityType.purchase,
        'bill-1',
      );
      expect(listed.map((a) => a.id), [scan.id]);
    });

    test('removing one never uploaded leaves nothing behind', () async {
      await insertPurchase('bill-1', SyncStatus.pending);
      final scan = await attach('bill-1');
      final copy = await AttachmentRepository.fileFor(scan);

      await repo.remove(scan);

      expect(copy.existsSync(), isFalse);
      expect(await dao.byId(scan.id), isNull);
    });

    test(
      'removing one already uploaded keeps a tombstone for the server',
      () async {
        await insertPurchase('bill-1', SyncStatus.synced);
        final scan = await attach('bill-1');
        await dao.markUploaded(scan.id, 'remote-1');

        await repo.remove((await dao.byId(scan.id))!);

        expect(
          await repo.forEntity(AttachmentEntityType.purchase, 'bill-1'),
          isEmpty,
        );
        final tombstones = await dao.awaitingRemoteDelete();
        expect(tombstones.single.remoteId, 'remote-1');
      },
    );
  });

  group('the gallery', () {
    Future<void> insertSupplier(String id, String name) => app.db.insert(
      DbTables.supplier,
      Supplier(id: id, createdAt: now, updatedAt: now, name: name).toMap(),
    );

    Future<void> insertBill(
      String id,
      String supplierId, {
      int billDate = now,
    }) => app.db.insert(
      DbTables.purchase,
      Purchase(
        id: id,
        createdAt: now,
        updatedAt: now,
        fiscalYearId: 'fy',
        supplierId: supplierId,
        billNo: id,
        billDate: billDate,
        amount: Money.fromWire('1000.00'),
      ).toMap(),
    );

    Future<void> insertPayment(String id, String supplierId) => app.db.insert(
      DbTables.supplierPayment,
      SupplierPayment(
        id: id,
        createdAt: now,
        updatedAt: now,
        fiscalYearId: 'fy',
        supplierId: supplierId,
        paymentDate: now,
        paymentMode: SupplierPaymentMode.cheque,
        amount: Money.fromWire('500.00'),
        chequeNo: 'CHQ-9',
      ).toMap(),
    );

    Future<void> scanPayment(String id, DocumentType type) async => repo.add(
      entityType: AttachmentEntityType.supplierPayment,
      entityId: id,
      documentType: type,
      sourcePath: await sourcePhoto('$id.jpg'),
    );

    setUp(() async {
      await insertSupplier('zeta', 'Zeta Traders');
      await insertSupplier('alpha', 'alpha Fabrics');
    });

    test('bills and receipts are kept apart', () async {
      await insertBill('bill-1', 'alpha');
      await attach('bill-1');
      await insertPayment('pay-1', 'alpha');
      await scanPayment('pay-1', DocumentType.chequeCopy);

      final bills = await repo.gallery(
        entityType: AttachmentEntityType.purchase,
      );
      expect(bills.map((s) => s.title), ['Bill bill-1']);

      final receipts = await repo.gallery(
        entityType: AttachmentEntityType.supplierPayment,
      );
      expect(receipts.map((s) => s.title), ['Cheque copy CHQ-9']);
    });

    test('suppliers come in name order, newest record first in each', () async {
      await insertBill('z-1', 'zeta');
      await insertBill('a-old', 'alpha', billDate: now - 1000);
      await insertBill('a-new', 'alpha');
      for (final id in ['z-1', 'a-old', 'a-new']) {
        await attach(id, name: '$id.jpg');
      }

      final scans = await repo.gallery(
        entityType: AttachmentEntityType.purchase,
      );

      expect(scans.map((s) => s.reference), ['a-new', 'a-old', 'z-1']);
      expect(scans.last.supplierName, 'Zeta Traders');
    });

    test('filters by supplier and by the date on the bill', () async {
      await insertBill('z-1', 'zeta');
      await insertBill('a-old', 'alpha', billDate: now - 1000);
      await insertBill('a-new', 'alpha');
      for (final id in ['z-1', 'a-old', 'a-new']) {
        await attach(id, name: '$id.jpg');
      }

      final bySupplier = await repo.gallery(
        entityType: AttachmentEntityType.purchase,
        supplierId: 'zeta',
      );
      expect(bySupplier.map((s) => s.reference), ['z-1']);

      final byDate = await repo.gallery(
        entityType: AttachmentEntityType.purchase,
        supplierId: 'alpha',
        fromMs: now - 1000,
        toMs: now - 1,
      );
      expect(byDate.map((s) => s.reference), ['a-old']);
    });

    test('leaves out removed scans and scans of deleted records', () async {
      await insertBill('removed', 'alpha');
      await insertBill('deleted', 'alpha');
      await insertBill('kept', 'alpha');
      final removed = await attach('removed', name: 'removed.jpg');
      await attach('deleted', name: 'deleted.jpg');
      await attach('kept', name: 'kept.jpg');

      await dao.markDeleted(removed.id);
      await app.db.update(
        DbTables.purchase,
        {SyncColumns.isDeleted: 1},
        where: 'id = ?',
        whereArgs: ['deleted'],
      );

      final scans = await repo.gallery(
        entityType: AttachmentEntityType.purchase,
      );
      expect(scans.map((s) => s.reference), ['kept']);
    });
  });

  group('taken on a form, before the record exists', () {
    test('files every photo against the record once it is saved', () async {
      final draft = ScanDraft(paper: 'receipt')
        ..photos.addAll([
          XFile(await sourcePhoto('receipt-1.jpg')),
          XFile(await sourcePhoto('receipt-2.jpg')),
        ]);

      final failed = await draft.attachTo(
        entityType: AttachmentEntityType.supplierPayment,
        entityId: 'pay-1',
        documentType: DocumentType.supplierPaymentReceipt,
      );

      expect(failed, 0);
      final filed = await repo.forEntity(
        AttachmentEntityType.supplierPayment,
        'pay-1',
      );
      expect(filed.map((a) => a.originalFileName), [
        'receipt-1.jpg',
        'receipt-2.jpg',
      ]);
      expect(
        filed.map((a) => a.documentType),
        everyElement(DocumentType.supplierPaymentReceipt),
      );
    });

    test(
      'one unreadable photo is counted and does not stop the rest',
      () async {
        final draft = ScanDraft(paper: 'bill')
          ..photos.addAll([
            XFile(p.join(sources.path, 'gone.jpg')),
            XFile(await sourcePhoto('bill.jpg')),
          ]);

        final failed = await draft.attachTo(
          entityType: AttachmentEntityType.purchase,
          entityId: 'bill-1',
          documentType: DocumentType.purchaseBill,
        );

        expect(failed, 1);
        final filed = await repo.forEntity(
          AttachmentEntityType.purchase,
          'bill-1',
        );
        expect(filed.map((a) => a.originalFileName), ['bill.jpg']);
      },
    );

    test('a payment scan waits for the payment to sync', () async {
      final scan = await repo.add(
        entityType: AttachmentEntityType.supplierPayment,
        entityId: 'pay-1',
        documentType: DocumentType.supplierPaymentReceipt,
        sourcePath: await sourcePhoto('receipt.jpg'),
      );

      Future<void> insertPayment(SyncStatus status) => app.db.insert(
        DbTables.supplierPayment,
        SupplierPayment(
          id: 'pay-1',
          createdAt: now,
          updatedAt: now,
          fiscalYearId: 'fy',
          supplierId: 'sup',
          paymentDate: now,
          paymentMode: SupplierPaymentMode.cash,
          amount: Money.fromWire('500.00'),
          syncStatus: status,
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await insertPayment(SyncStatus.pending);
      expect(await dao.awaitingUpload(), isEmpty);

      await insertPayment(SyncStatus.synced);
      expect((await dao.awaitingUpload()).map((a) => a.id), [scan.id]);
    });
  });

  group('the uploader', () {
    late FakeAttachmentApi api;
    late AttachmentUploader uploader;

    setUp(() {
      api = FakeAttachmentApi();
      uploader = AttachmentUploader(
        dao: dao,
        api: api,
        fileFor: AttachmentRepository.fileFor,
      );
    });

    test('waits for the bill to reach the server first', () async {
      await insertPurchase('unsynced', SyncStatus.pending);
      await insertPurchase('synced', SyncStatus.synced);
      final waiting = await attach('unsynced');
      final ready = await attach('synced');

      expect(await uploader.run(), 1);

      expect(api.uploaded.map((u) => u['entityId']), ['synced']);
      expect(api.uploaded.single['entityType'], 'PURCHASE');
      expect(api.uploaded.single['documentType'], 'PURCHASE_BILL');
      expect(api.uploaded.single['mimeType'], 'image/jpeg');
      expect((await dao.byId(ready.id))!.remoteId, 'remote-1');
      expect((await dao.byId(waiting.id))!.remoteId, isNull);

      // Nothing left to send on a second run.
      expect(await uploader.run(), 0);
    });

    test('records a refusal and carries on with the rest', () async {
      await insertPurchase('synced', SyncStatus.synced);
      final rejected = await attach('synced', name: 'a.jpg');
      final accepted = await attach('synced', name: 'b.jpg');
      api.failNextUpload = const NetworkException('Too large', statusCode: 413);

      await uploader.run();

      final first = (await dao.byId(rejected.id))!;
      expect(first.remoteId, isNull);
      expect(first.uploadError, 'Too large');
      expect((await dao.byId(accepted.id))!.isUploaded, isTrue);
    });

    test('stops at a lost connection and leaves everything queued', () async {
      await insertPurchase('synced', SyncStatus.synced);
      await attach('synced', name: 'a.jpg');
      await attach('synced', name: 'b.jpg');
      api.failNextUpload = const NetworkException('No route to host');

      expect(await uploader.run(), 0);

      expect(api.uploadAttempts, 1);
      expect(await dao.awaitingUpload(), hasLength(2));
      expect((await dao.awaitingUpload()).first.uploadError, isNull);
    });

    test('deletes on the server what was removed here', () async {
      await insertPurchase('synced', SyncStatus.synced);
      final gone = await attach('synced', name: 'a.jpg');
      final alreadyGone = await attach('synced', name: 'b.jpg');
      await dao.markUploaded(gone.id, 'remote-a');
      await dao.markUploaded(alreadyGone.id, 'remote-b');
      await dao.markDeleted(gone.id);
      await dao.markDeleted(alreadyGone.id);
      api.missingOnServer.add('remote-b');

      expect(await uploader.run(), 2);

      expect(api.deleted, ['remote-a', 'remote-b']);
      expect(await dao.byId(gone.id), isNull);
      expect(await dao.byId(alreadyGone.id), isNull);
    });
  });
}

class FakeAttachmentApi implements AttachmentApi {
  final List<Map<String, String>> uploaded = [];
  final List<String> deleted = [];
  final Set<String> missingOnServer = {};
  NetworkException? failNextUpload;
  int uploadAttempts = 0;

  @override
  bool get isConfigured => true;

  @override
  Future<String> upload({
    required String entityType,
    required String entityId,
    required String documentType,
    required String filePath,
    required String fileName,
    required String mimeType,
  }) async {
    uploadAttempts++;
    final failure = failNextUpload;
    if (failure != null) {
      failNextUpload = null;
      throw failure;
    }
    uploaded.add({
      'entityType': entityType,
      'entityId': entityId,
      'documentType': documentType,
      'fileName': fileName,
      'mimeType': mimeType,
    });
    return 'remote-${uploaded.length}';
  }

  @override
  Future<void> delete(String remoteId) async {
    deleted.add(remoteId);
    if (missingOnServer.contains(remoteId)) {
      throw const NetworkException('Not found', statusCode: 404);
    }
  }
}
