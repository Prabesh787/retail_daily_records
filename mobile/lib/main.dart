import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/bindings/initial_binding.dart';
import 'app/core/constants/app_strings.dart';
import 'app/core/theme/app_theme.dart';
import 'app/data/providers/remote/api_client.dart';
import 'app/data/providers/remote/auth_api.dart';
import 'app/routes/app_pages.dart';
import 'app/services/auth_service.dart';
import 'app/services/connectivity_service.dart';
import 'app/services/data_change_service.dart';
import 'app/services/database_service.dart';
import 'app/services/storage_service.dart';
import 'app/services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Services are awaited before the first frame: no screen can render against a
  // database that is not open or settings that are not loaded. Order matters -
  // SyncService reads the others.
  Get.put(DataChangeService(), permanent: true);
  await Get.putAsync(() => StorageService().init(), permanent: true);
  await Get.putAsync(() => DatabaseService().init(), permanent: true);
  await Get.putAsync(() => ConnectivityService().init(), permanent: true);

  // One HTTP client for auth and sync, so a token cleared by a 401 on either
  // path is gone for both. Registered before AuthService because the service is
  // built on it; the client resolves the service lazily, per request, which is
  // what lets the two depend on each other.
  Get.put(InitialBinding.buildApiClient(), permanent: true);
  Get.put(AuthApi(Get.find<ApiClient>()), permanent: true);
  await Get.putAsync(
    () => AuthService(Get.find<AuthApi>()).init(),
    permanent: true,
  );

  InitialBinding().dependencies();

  await Get.putAsync(() => SyncService().init(), permanent: true);

  runApp(const BillRecordApp());
}

class BillRecordApp extends StatelessWidget {
  const BillRecordApp({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = Get.find<StorageService>();

    return GetMaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: storage.isDarkMode ? ThemeMode.dark : ThemeMode.system,
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
      defaultTransition: Transition.cupertino,
    );
  }
}
