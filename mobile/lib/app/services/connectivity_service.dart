import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

/// Tracks whether the device has a network interface.
///
/// Deliberately only a hint, not a gate: connectivity_plus reports the radio,
/// not whether the server is reachable, so the sync engine still has to handle
/// a request failing while this says "online". What it is genuinely good for is
/// the opposite direction — not wasting a push attempt while clearly offline,
/// and firing one the moment the shop's wifi comes back.
class ConnectivityService extends GetxService {
  static ConnectivityService get to => Get.find();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final RxBool isOnline = true.obs;

  /// Emits only on the offline -> online edge, which is when a sync is worth
  /// triggering. Listening to every connectivity event would re-sync on any
  /// interface change.
  final _reconnected = StreamController<void>.broadcast();
  Stream<void> get onReconnected => _reconnected.stream;

  Future<ConnectivityService> init() async {
    isOnline.value = _resolve(await _connectivity.checkConnectivity());
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = isOnline.value;
      isOnline.value = _resolve(results);
      if (!wasOnline && isOnline.value) _reconnected.add(null);
    });
    return this;
  }

  bool _resolve(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  void onClose() {
    _subscription?.cancel();
    _reconnected.close();
    super.onClose();
  }
}
