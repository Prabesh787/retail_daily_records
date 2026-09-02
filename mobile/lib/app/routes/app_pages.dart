import 'package:get/get.dart';

import '../modules/auth/bindings/auth_binding.dart';
import '../modules/auth/views/login_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/splash/bindings/splash_binding.dart';
import '../modules/splash/views/splash_view.dart';
import 'auth_guard.dart';

part 'app_routes.dart';

/// Every route, its page and its binding.
///
/// The addresses mirror the web app's route table, so a screen is at the same
/// path in both.
///
/// Everything except the splash and login carries [AuthGuard]. The app serves
/// several shops off one backend and every record belongs to one of them, so
/// there is no screen worth showing without knowing whose books are open.
class AppPages {
  AppPages._();

  static const String initial = Routes.splash;

  /// Applied to every screen behind the login.
  static final List<GetMiddleware> _protected = [AuthGuard()];

  static final List<GetPage<dynamic>> routes = [
    GetPage(
      name: Routes.splash,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: Routes.login,
      page: () => const LoginView(),
      binding: AuthBinding(),
      middlewares: [GuestOnly()],
    ),
    GetPage(
      name: Routes.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
      middlewares: _protected,
    ),
  ];
}
