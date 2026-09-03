import 'package:billrecord/app/core/constants/db_constants.dart';
import 'package:billrecord/app/services/data_change_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The change bus is what replaces React Query's `invalidateQueries` on this
/// side. Every list in the app depends on it to notice that a bill was saved or
/// that sync brought rows down, so its three promises are pinned here: a
/// watcher hears about the entities it asked for, it does not hear about the
/// others, and a burst arrives as one event rather than as one per row.
void main() {
  late DataChangeService bus;

  setUp(() => bus = DataChangeService());
  tearDown(() => bus.onClose());

  // Long enough to clear the coalescing window with room to spare.
  Future<void> settle() => Future<void>.delayed(
    const Duration(milliseconds: 220),
  );

  test('a watcher hears about the entity it asked for', () async {
    var calls = 0;
    final sub = bus.watch([DbTables.supplier], () => calls++);

    bus.publish([DbTables.supplier]);
    await settle();

    expect(calls, 1);
    await sub.cancel();
  });

  test('a watcher does not hear about entities it did not ask for', () async {
    var calls = 0;
    final sub = bus.watch([DbTables.sale], () => calls++);

    bus.publish([DbTables.supplier]);
    await settle();

    expect(calls, 0);
    await sub.cancel();
  });

  test('a supplier list watching bills hears about a saved bill', () async {
    // The case the whole design exists for: no supplier row was written, but
    // every balance on that screen is derived from purchases.
    var calls = 0;
    final sub = bus.watch(
      [DbTables.supplier, DbTables.purchase, DbTables.supplierPayment],
      () => calls++,
    );

    bus.publish([DbTables.purchase]);
    await settle();

    expect(calls, 1);
    await sub.cancel();
  });

  test('a burst of writes arrives as one event', () async {
    var calls = 0;
    final sub = bus.watch([DbTables.purchase], () => calls++);

    // A sync pull landing a page of rows, or a save that touches several
    // tables. Reloading a list once per row would be the same query run two
    // hundred times for one answer.
    for (var i = 0; i < 200; i++) {
      bus.publish([DbTables.purchase]);
    }
    await settle();

    expect(calls, 1);
    await sub.cancel();
  });

  test('separate bursts are separate events', () async {
    var calls = 0;
    final sub = bus.watch([DbTables.sale], () => calls++);

    bus.publish([DbTables.sale]);
    await settle();
    bus.publish([DbTables.sale]);
    await settle();

    expect(calls, 2);
    await sub.cancel();
  });

  test('one publish can wake watchers of different entities', () async {
    var supplierCalls = 0;
    var saleCalls = 0;
    final a = bus.watch([DbTables.supplier], () => supplierCalls++);
    final b = bus.watch([DbTables.sale], () => saleCalls++);

    bus.publish([DbTables.supplier, DbTables.sale]);
    await settle();

    expect(supplierCalls, 1);
    expect(saleCalls, 1);
    await a.cancel();
    await b.cancel();
  });

  test('a cancelled watcher stops hearing anything', () async {
    var calls = 0;
    final sub = bus.watch([DbTables.supplier], () => calls++);
    await sub.cancel();

    bus.publish([DbTables.supplier]);
    await settle();

    // A controller that forgot this would keep reloading a disposed screen for
    // the life of the app.
    expect(calls, 0);
  });

  test('publishing after close is harmless', () async {
    bus.onClose();

    // A repository can outlive the service graph during a sign-out teardown,
    // and a write completing at that moment must not throw on the way out.
    expect(() => bus.publish([DbTables.supplier]), returnsNormally);

    // The tearDown closes it again; that must be safe too.
  });
}
