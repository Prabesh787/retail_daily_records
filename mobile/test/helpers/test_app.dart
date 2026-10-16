import 'dart:async';
import 'dart:io';

import 'package:billrecord/app/core/theme/app_theme.dart';
import 'package:billrecord/app/data/providers/remote/api_client.dart';
import 'package:billrecord/app/data/providers/remote/auth_api.dart';
import 'package:billrecord/app/data/providers/remote/retail_api.dart';
import 'package:billrecord/app/data/repositories/customer_repository.dart';
import 'package:billrecord/app/data/repositories/dashboard_repository.dart';
import 'package:billrecord/app/data/repositories/fiscal_year_repository.dart';
import 'package:billrecord/app/data/repositories/purchase_repository.dart';
import 'package:billrecord/app/data/repositories/sale_repository.dart';
import 'package:billrecord/app/data/repositories/supplier_payment_repository.dart';
import 'package:billrecord/app/data/repositories/supplier_repository.dart';
import 'package:billrecord/app/services/auth_service.dart';
import 'package:billrecord/app/services/data_change_service.dart';
import 'package:billrecord/app/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'fake_backend.dart';

/// Enough of the app to mount a real screen in a test.
///
/// Nothing here is a mock of the app's own code: the repositories are the real
/// ones, the HTTP client is the real one, and only the transport underneath it
/// is swapped for [FakeBackend]. A screen test whose data layer is fake mostly
/// proves the fake works.
class TestApp {
  TestApp._(this.backend, this._storageDir);

  /// The server the app is talking to. Seed through it, or assert on what was
  /// asked of it.
  final FakeBackend backend;

  final Directory _storageDir;

  /// Registers the service graph over an in-memory API and returns the handle.
  /// Call [dispose] in `tearDown`.
  static Future<TestApp> start({bool signedIn = true}) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // `GetStorage` asks path_provider where to write, and path_provider has no
    // implementation under `flutter test`. Pointing it at a scratch directory
    // is what lets the real StorageService run rather than being mocked out.
    final storageDir = await Directory.systemTemp.createTemp('billrecord_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => storageDir.path,
    );

    final backend = FakeBackend();

    Get.testMode = true;
    Get.put(DataChangeService(), permanent: true);
    Get.put<StorageService>(await StorageService().init(), permanent: true);

    Get.put<ApiClient>(
      ApiClient(
        baseUrl: 'https://shop.test/api/v1',
        adapter: backend,
        tokenProvider: () =>
            Get.isRegistered<AuthService>() ? AuthService.to.token : null,
        onUnauthorized: () {
          if (Get.isRegistered<AuthService>()) AuthService.to.onUnauthorized();
        },
      ),
      permanent: true,
    );
    Get.put(AuthApi(Get.find<ApiClient>()), permanent: true);
    Get.put<AuthService>(
      await AuthService(Get.find<AuthApi>()).init(),
      permanent: true,
    );

    // Screens that show who is signed in need a session. Started signed in
    // because that is the only state the app runs in — every screen but the
    // login form is behind the guard.
    if (signedIn) {
      await AuthService.to.signIn(email: 'admin@shop.test', password: 'x');
    }

    Get.put<RetailApi>(RetailApi(Get.find<ApiClient>()), permanent: true);
    Get.put(FiscalYearRepository(), permanent: true);
    Get.put(SupplierRepository(), permanent: true);
    Get.put(CustomerRepository(), permanent: true);
    Get.put(PurchaseRepository(), permanent: true);
    Get.put(SupplierPaymentRepository(), permanent: true);
    Get.put(SaleRepository(), permanent: true);
    Get.put(DashboardRepository(), permanent: true);

    return TestApp._(backend, storageDir);
  }

  Future<void> dispose() async {
    // `Get.reset()` rather than `deleteAll`: GetX keeps global routing state
    // alongside its instances, and leaving that behind makes the next test's
    // navigation to the same route name a no-op — the screen never mounts and
    // every finder in it comes back empty.
    Get.reset();

    // The scratch directory GetStorage wrote into. Best-effort: GetStorage may
    // still hold the file open, and on Windows that makes the delete throw —
    // which would fail a test that had already passed.
    try {
      if (_storageDir.existsSync()) _storageDir.deleteSync(recursive: true);
    } on FileSystemException {
      // The OS will clear it with the rest of the temp directory.
    }
  }
}

/// Mounts [screen] the way the app does: through the router, inside
/// `GetMaterialApp`, so bindings run, `Get.arguments` is populated and the
/// theme is the real one.
///
/// It navigates rather than dropping the widget in as `home`, because
/// [arguments] is how every detail screen learns which record it is showing —
/// and a controller that read `Get.arguments` from a screen that was never
/// routed to would be tested in a state the app never produces.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Bindings? binding,
  Map<String, dynamic>? arguments,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    GetMaterialApp(
      theme: theme ?? AppTheme.light,
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: _blank),
        GetPage(name: '/target', page: () => screen, binding: binding),
      ],
    ),
  );

  // Not awaited: `Get.toNamed` completes when the route is *popped*, not when
  // it is pushed, so awaiting it here waits forever for a screen the test is
  // about to inspect.
  unawaited(Get.toNamed<void>('/target', arguments: arguments) ?? Future.value());
  await settle(tester);
}

/// Runs a write from inside a widget test.
///
/// `testWidgets` runs its body in a fake-async zone where the plugin and file
/// I/O `GetStorage` performs never completes, so seeding through a repository
/// without this can simply hang. `runAsync` steps out to the real zone for the
/// duration of the write.
Future<T> seed<T>(WidgetTester tester, Future<T> Function() write) async {
  late T result;
  await tester.runAsync(() async => result = await write());
  return result;
}

/// Advances the screen past its loading state.
///
/// Deliberately **not** `pumpAndSettle`: the loading skeleton shimmers on a
/// `..repeat()` controller, so there is always another frame scheduled and
/// `pumpAndSettle` waits for a quiet that never comes.
///
/// So: pump a frame to build the skeleton and start the fetch, step outside
/// fake-async to let the request actually run, then pump again to rebuild with
/// what came back.
Future<void> settle(WidgetTester tester, {int rounds = 3}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Widget _blank() => const SizedBox.shrink();
