import 'dart:async';

import 'package:get/get.dart';

/// Announces that records of an entity have changed, so open screens reload.
///
/// The web app gets this from React Query: a mutation invalidates a key and
/// every mounted list refetches. There is no equivalent in GetX, and the naive
/// substitutes fail in exactly the cases that matter. Reloading in `onInit`
/// misses a dashboard sitting behind the form that just saved a bill; reloading
/// when a `Get.toNamed` returns misses a screen two tabs away that is showing
/// the same figures.
///
/// So the signal is attached to the write itself. Every write goes through
/// `BaseRepository.write`, which publishes here once the server has accepted
/// it, and a controller that has said which entities it shows gets told.
///
/// Entity names are the ones in [Entities], which are also the API's path
/// segments. One vocabulary for the whole data layer.
class DataChangeService extends GetxService {
  static DataChangeService get to => Get.find();

  final StreamController<Set<String>> _controller =
      StreamController<Set<String>>.broadcast();

  /// Batched rather than fired per write: saving a sale touches the sale and
  /// leaves three screens wanting a reload, and they have no use for three
  /// separate rounds of it.
  final Set<String> _pending = <String>{};
  Timer? _flush;

  /// How long a burst of writes is allowed to coalesce. Short enough that a
  /// save still feels immediate, long enough that a form saving several things
  /// in a row produces one event.
  static const Duration _window = Duration(milliseconds: 120);

  /// Records that [entities] changed. Safe to call from anywhere.
  void publish(Iterable<String> entities) {
    if (_controller.isClosed) return;
    _pending.addAll(entities);
    if (_pending.isEmpty) return;

    _flush ??= Timer(_window, _emit);
  }

  void _emit() {
    _flush = null;
    if (_pending.isEmpty || _controller.isClosed) return;

    _controller.add(Set.unmodifiable(_pending));
    _pending.clear();
  }

  /// Calls [onChanged] whenever any of [entities] is written.
  ///
  /// The returned subscription is the caller's to cancel — a controller does it
  /// in `onClose`, and forgetting to leaves a dead screen reloading in the
  /// background for the life of the app.
  StreamSubscription<Set<String>> watch(
    Iterable<String> entities,
    void Function() onChanged,
  ) {
    final wanted = entities.toSet();
    return _controller.stream
        .where((changed) => changed.any(wanted.contains))
        .listen((_) => onChanged());
  }

  /// Every change, for a screen that genuinely shows all of them — the
  /// dashboard is the only honest case.
  Stream<Set<String>> get changes => _controller.stream;

  @override
  void onClose() {
    _flush?.cancel();
    _controller.close();
    super.onClose();
  }
}
