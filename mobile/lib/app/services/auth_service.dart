import 'dart:convert';

import 'package:get/get.dart';

import '../core/constants/db_constants.dart';
import '../core/errors/app_exception.dart';
import '../data/models/app_user.dart';
import '../data/providers/remote/auth_api.dart';
import 'storage_service.dart';

/// Who is signed in.
///
/// **Signing in is required.** The app serves several shops off one hosted
/// backend, and every record belongs to exactly one of them, so there is no
/// meaningful "just start recording" state: without an account the app does not
/// know whose books it is opening.
///
/// That means a session ending — token expired, revoked, account switched off —
/// puts the user back at the login screen, and until the offline work is done
/// it also means the app needs a connection to open. [signOut] and
/// [onUnauthorized] are therefore the same act, and both end at the front door.
class AuthService extends GetxService {
  AuthService(this._api);

  static AuthService get to => Get.find();

  final AuthApi _api;
  StorageService get _storage => Get.find<StorageService>();

  final Rxn<AppUser> user = Rxn<AppUser>();

  Future<AuthService> init() async {
    // Both halves or neither. A cached account with no token cannot make a
    // request, and a token with no cached account has nobody to show - either
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

  String? get token => _storage.authToken;

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
    if (!_api.isConfigured) {
      throw const NetworkException(
        'This build has no server address set, so there is nothing to sign in '
        'to. Rebuild with API_BASE_URL pointing at the shop server.',
      );
    }

    final result = await _api.login(email: email, password: password);
    _storage.authToken = result.token;
    _cacheUser(result.user);
    return result.user;
  }

  /// Re-reads the account. Used after opening the app to pick up a shop detail
  /// or a role changed elsewhere.
  ///
  /// A transport failure is swallowed: the cached copy is what every screen
  /// reads and is still the best answer available. A rejected token is not
  /// swallowed - [ApiClient] has already cleared the session by then.
  Future<void> refresh() async {
    if (!isSignedIn) return;
    try {
      _cacheUser(await _api.me());
    } on AppException {
      // Offline or a blip. The cache stands.
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
  /// It is safe to call more than once - a second call finds nothing to clear
  /// and no route to change.
  Future<void> onUnauthorized() async {
    if (!isSignedIn) return;
    await signOut(message: 'Your session has ended. Please sign in again.');
  }

  /// Ends the session and shows the login screen.
  ///
  /// Local rows are deliberately **not** deleted: they may include work this
  /// device has not managed to send yet, and throwing that away because a token
  /// lapsed would be losing the shop's records to fix a login problem. Clearing
  /// them is a separate, louder action.
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
    _storage.authToken = null;
    _storage.cachedUser = null;
    // The next account to sign in on this phone must pull its own history from
    // the beginning rather than inherit a cursor claiming someone else's
    // records are already up to date.
    await _storage.clearCursors();
    user.value = null;
  }

  void _cacheUser(AppUser value) {
    user.value = value;
    _storage.cachedUser = jsonEncode(value.toJson());
  }

  AppUser? _cachedUser() {
    final raw = _storage.cachedUser;
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

/// Storage keys owned by this service, kept in [StorageKeys] with the others so
/// nothing collides and one `erase()` clears everything.
extension AuthStorage on StorageService {
  String? get authToken => readString(StorageKeys.authToken);
  set authToken(String? value) => writeString(StorageKeys.authToken, value);

  String? get cachedUser => readString(StorageKeys.cachedUser);
  set cachedUser(String? value) => writeString(StorageKeys.cachedUser, value);
}
