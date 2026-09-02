import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../services/auth_service.dart';

/// Sends anyone without a session to the login screen.
///
/// Applied per route rather than checked inside each screen, so a screen added
/// later is protected by declaring its route rather than by someone remembering
/// to add a check. Forgetting the guard is then a visible omission in the route
/// table instead of an invisible hole in a widget.
///
/// It runs on every navigation, not only at startup, which is what closes the
/// gap where a session ends mid-use: the 401 clears the session, and the next
/// route change lands here.
class AuthGuard extends GetMiddleware {
  AuthGuard();

  @override
  RouteSettings? redirect(String? route) {
    // The service may not be registered yet in a test or a deep link opened
    // before startup finished. Absent means unauthenticated, which is the safe
    // reading.
    final signedIn =
        Get.isRegistered<AuthService>() && AuthService.to.isSignedIn;

    return signedIn ? null : const RouteSettings(name: '/login');
  }
}

/// The reverse: keeps a signed-in user off the login screen.
///
/// Without it, the back gesture from home lands on a login form the user has
/// already passed, which reads as being signed out.
class GuestOnly extends GetMiddleware {
  GuestOnly();

  @override
  RouteSettings? redirect(String? route) {
    final signedIn =
        Get.isRegistered<AuthService>() && AuthService.to.isSignedIn;

    return signedIn ? const RouteSettings(name: '/home') : null;
  }
}
