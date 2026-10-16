import '../../../core/errors/app_exception.dart';
import '../../models/app_user.dart';
import 'api_client.dart';

/// The three auth calls the app makes.
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
    final response = await _client.post(
      '/auth/login',
      body: {'email': email.trim().toLowerCase(), 'password': password},
    );

    final data = response.object;
    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw const NetworkException('The server did not return a sign-in token.');
    }
    return (token: token, user: AppUser.fromJson(data));
  }

  Future<AppUser> me() async =>
      AppUser.fromJson((await _client.get('/auth/me')).object);

  /// Only the keys sent are written, so the shop form can leave the account
  /// name alone.
  Future<AppUser> updateMe(Map<String, dynamic> body) async =>
      AppUser.fromJson((await _client.patch('/auth/me', body: body)).object);
}
