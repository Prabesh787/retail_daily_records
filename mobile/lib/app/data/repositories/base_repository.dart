import 'package:get/get.dart';

import '../../core/utils/nepali_date.dart';
import '../../services/data_change_service.dart';
import '../providers/remote/retail_api.dart';

/// Shared plumbing for the repositories.
///
/// Repositories are the layer that knows the API exists. Controllers call them
/// and get models back; nothing above this layer sees a path, a query string or
/// a JSON map.
///
/// They are also where a successful write is announced, so a screen showing the
/// same records reloads. The web app gets that from React Query invalidating a
/// key after a mutation; here it is [DataChangeService], and the signal is
/// attached to the write rather than to a navigation, so a dashboard sitting
/// behind the form that just saved a bill is told too.
abstract class BaseRepository {
  /// What this repository owns. Also the key screens watch it under, and the
  /// segment its endpoints live at. See [Entities].
  String get entity;

  RetailApi get api => Get.find<RetailApi>();

  /// Runs a write and announces it once it has actually landed.
  ///
  /// Announcing after rather than before matters: a screen told to reload while
  /// the request is still open reads the records as they were before it.
  Future<T> write<T>(Future<T> Function() action) async {
    final result = await action();
    announce([entity]);
    return result;
  }

  /// Tells any open screen showing [entities] that its rows have moved.
  ///
  /// A writer names only what it actually touched. A supplier's outstanding
  /// changes when a bill is saved, but it is the supplier *list* that knows it
  /// depends on purchases — so the watcher declares its dependencies and the
  /// writer stays honest.
  ///
  /// Guarded because the tests build repositories without the service graph.
  void announce(Iterable<String> entities) {
    if (Get.isRegistered<DataChangeService>()) {
      Get.find<DataChangeService>().publish(entities);
    }
  }

  /// A date window as the API takes it: inclusive `?from=&to=` in AD
  /// `YYYY-MM-DD`, with an absent bound simply left out.
  ///
  /// The screens work in epoch millis because that is what a date picker and a
  /// sort both want; the conversion belongs here rather than in each caller, or
  /// one of them will eventually send a local midnight and shift a day.
  Map<String, dynamic> window({int? fromMs, int? toMs}) => {
        if (fromMs != null) 'from': _isoDate(fromMs),
        if (toMs != null) 'to': _isoDate(toMs),
      };

  String _isoDate(int ms) => NepaliDate.toIsoDate(NepaliDate.fromMs(ms));

  /// The largest page the API will serve.
  ///
  /// Asking for more is not an error — the server clamps it — but a screen that
  /// thinks it asked for 500 rows and drew 100 would report a total for a list
  /// it does not have. So the clamp happens on this side too, where the caller
  /// can see it.
  static const int maxPageSize = 100;

  int pageSize(int? limit) =>
      limit == null ? maxPageSize : limit.clamp(1, maxPageSize);
}
