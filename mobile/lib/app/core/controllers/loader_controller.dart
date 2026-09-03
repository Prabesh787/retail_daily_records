import 'dart:async';

import 'package:get/get.dart';

import '../../services/data_change_service.dart';
import '../errors/app_exception.dart';

/// The shape every screen that reads something shares.
///
/// Three things go wrong when each screen invents its own version of this, and
/// all three are in the app before anyone notices:
///
///   * the error state gets skipped, because the happy path is what gets built
///     and a failed query just leaves an empty list that reads as "no records";
///   * a reload triggered by a write flashes a skeleton over data that is
///     already on screen and perfectly good;
///   * one screen forgets to cancel its change subscription and keeps
///     reloading in the background for the life of the app.
///
/// So the pattern lives here once. A subclass says what to fetch and which
/// entities to watch, and gets the four states and the subscription for free.
abstract class LoaderController<T> extends GetxController {
  /// What the screen shows. Null until the first load lands.
  final Rxn<T> data = Rxn<T>();

  /// True only while there is nothing to show yet. A refresh over existing data
  /// leaves this false — see [load].
  final RxBool isLoading = true.obs;

  final RxnString error = RxnString();

  StreamSubscription<void>? _changes;

  /// Reads the data. Anything thrown is caught and surfaced as [error].
  Future<T> fetch();

  /// Entities whose writes should reload this screen.
  ///
  /// Declared by the *watcher*, not the writer, and it must name everything the
  /// screen's figures derive from — not just the obvious one. A supplier list
  /// shows balances computed from bills and payments, so saving a bill has to
  /// reload it even though no supplier row was touched.
  List<String> get watches => const [];

  /// Whether [fetch] returned something worth drawing. Overridden by list
  /// screens so an empty result shows the empty state rather than a blank page.
  bool get isEmpty => data.value == null;

  @override
  void onInit() {
    super.onInit();

    if (watches.isNotEmpty && Get.isRegistered<DataChangeService>()) {
      // Silent: the rows changed underneath a screen the user is already
      // looking at, and replacing it with a skeleton would be a worse lie than
      // the stale data it is fixing.
      _changes = DataChangeService.to.watch(watches, () => load(silent: true));
    }

    load();
  }

  /// Runs [fetch] and moves the screen into whichever state results.
  ///
  /// [silent] keeps whatever is on screen while the new read runs. Used for
  /// every reload that the user did not personally ask for.
  Future<void> load({bool silent = false}) async {
    if (!silent) isLoading.value = true;

    try {
      data.value = await fetch();
      error.value = null;
    } on AppException catch (e) {
      // Our own exceptions carry a message written for a shopkeeper.
      error.value = e.message;
    } catch (e) {
      error.value = 'Something went wrong reading this. $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// What pull-to-refresh and the error state's retry both call.
  ///
  /// Named `reload` rather than `refresh` on purpose: `GetxController` already
  /// has a `refresh()` that rebuilds observers without re-reading anything, and
  /// two methods a letter apart doing very different things is a bug waiting
  /// for whoever types the wrong one.
  Future<void> reload() => load(silent: data.value != null);

  @override
  void onClose() {
    _changes?.cancel();
    super.onClose();
  }
}
