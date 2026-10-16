import 'dart:convert';

import 'package:get/get.dart';

import '../core/constants/entities.dart';
import '../core/errors/app_exception.dart';
import '../data/models/app_user.dart';
import '../data/providers/remote/auth_api.dart';
import 'storage_service.dart';

/// Who is signed in.
///
/// **Signing in is required.** The app serves several shops off one hosted
/// backend, every record belongs to exactly one of them, and the records live
/// on the server — so without an account there is nothing to show and no way to
/// know whose books to show it from.
///
/// That means a session ending — token expired, revoked, account switched off —
/// puts the user back at the login screen. [signOut] and [onUnauthorized] are
/// therefore the same act, and both end at the front door.
class AuthService extends GetxService {
  AuthService(this._api);

  static AuthService get to => Get.find();

  final AuthApi _api;
  StorageService get _storage => Get.find<StorageService>();

  final Rxn<AppUser> user = Rxn<AppUser>();

  Future<AuthService> init() async {
    // Both halves or neither. A cached account with no token cannot make a
    // request, and a token with no cached account has nobody to show — either
    // way the only honest answer is "signed out".
    final cached = _cachedUser();
    if (cached != null && (token ?? '').isNotEmpty) {
      user.value = cached;
    } else {
      await _clearSession();
    }
    return this;
  }

  /// The gate every protected route asks. True only with an account **and** a
  /// token.
  bool get isSignedIn => user.value != null && (token ?? '').isNotEmpty;

  /// Whether this build has a server to sign in to at all.
  ///
  /// False is a misconfigured build rather than a mode: the app cannot be used
  /// without one, and the login screen says so plainly instead of offering a
  /// form that cannot work.
  bool get canSignIn => _api.isConfigured;

  String? get token => _storage.readString(StorageKeys.authToken);

  Shop get shop => user.value?.shop ?? const Shop();

  String get shopName {
    final name = shop.name?.trim();
    return (name == null || name.isEmpty) ? 'Shop' : name;
  }

  String get accountName => user.value?.name ?? '';

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final result = await _api.login(email: email, password: password);
    _storage.writeString(StorageKeys.authToken, result.token);
    _cacheUser(result.user);
    return result.user;
  }

  /// Re-reads the account, to pick up a shop detail or a role changed
  /// elsewhere, and to discover a token revoked since last launch.
  ///
  /// A transport failure is swallowed: the cached copy is only a name in a
  /// header, and losing the connection for a moment is not a reason to throw
  /// the user out. A rejected token is not swallowed — [ApiClient] has already
  /// ended the session by then.
  Future<void> refresh() async {
    if (!isSignedIn) return;
    try {
      _cacheUser(await _api.me());
    } on AppException {
      // A blip. The cached name stands until the next screen asks the server
      // for something that actually matters.
    }
  }

  Future<AppUser> updateShop(Shop shop) async {
    final updated = await _api.updateMe({
      'shopName': shop.name,
      'shopAddress': shop.address,
      'shopPhone': shop.phone,
      'shopPan': shop.pan,
    });
    _cacheUser(updated);
    return updated;
  }

  /// The server rejected the token: expired, revoked, or the account switched
  /// off. Ends the session and returns to the front door.
  ///
  /// Called from the HTTP client, so it can fire from any screen at any moment.
  /// Safe to call more than once — a second call finds nothing to clear and no
  /// route to change.
  Future<void> onUnauthorized() async {
    if (!isSignedIn) return;
    await signOut(message: 'Your session has ended. Please sign in again.');
  }

  Future<void> signOut({String? message}) async {
    await _clearSession();
    Get.offAllNamed(_loginRoute);
    if (message != null) {
      Get.snackbar('Signed out', message, snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// Named rather than imported, to keep this service free of a dependency on
  /// the route table.
  static const String _loginRoute = '/login';

  Future<void> _clearSession() async {
    _storage
      ..writeString(StorageKeys.authToken, null)
      ..writeString(StorageKeys.cachedUser, null);
    user.value = null;
  }

  void _cacheUser(AppUser value) {
    user.value = value;
    _storage.writeString(StorageKeys.cachedUser, jsonEncode(value.toJson()));
  }

  AppUser? _cachedUser() {
    final raw = _storage.readString(StorageKeys.cachedUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return AppUser.fromJson(decoded);
    } on FormatException {
      // A corrupted cache just means signing in again.
    }
    return null;
  }
}
