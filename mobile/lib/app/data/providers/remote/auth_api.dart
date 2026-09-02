import '../../../core/errors/app_exception.dart';
import '../../models/app_user.dart';
import 'api_client.dart';

/// The three auth calls the app makes.
///
/// The API wraps every response in `{ success, message, data }`; unwrapping
/// happens here so nothing above this layer knows the envelope exists.
class AuthApi {
  const AuthApi(this._client);

  final ApiClient _client;

  bool get isConfigured => _client.isConfigured;

  /// `POST /auth/login` — the only endpoint reachable without a token.
  ///
  /// Returns the token and the account together, so a successful sign-in needs
  /// no second round trip before the shop's name can be shown.
  Future<({String token, AppUser user})> login({
    required String email,
    required String password,
  }) async {
    final json = await _client.post(
      '/auth/login',
      body: {'email': email.trim().toLowerCase(), 'password': password},
    );

    final data = _unwrap(json);
    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw const NetworkException('The server did not return a sign-in token.');
    }
    return (token: token, user: AppUser.fromJson(data));
  }

  Future<AppUser> me() async {
    return AppUser.fromJson(_unwrap(await _client.get('/auth/me')));
  }

  /// Only the keys sent are written, so the shop form can leave the account
  /// name alone.
  Future<AppUser> updateMe(Map<String, dynamic> body) async {
    return AppUser.fromJson(_unwrap(await _client.patch('/auth/me', body: body)));
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    final data = json['data'];
    return data is Map<String, dynamic> ? data : json;
  }
}
