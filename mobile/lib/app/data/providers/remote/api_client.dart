import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';

/// Thin Dio wrapper. Its only jobs are attaching auth, keeping timeouts sane
/// for a shop on a weak mobile connection, and translating transport errors
/// into [NetworkException] so nothing above this layer imports Dio.
class ApiClient {
  ApiClient({String? baseUrl, this.tokenProvider, this.onUnauthorized})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? '',
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
            contentType: 'application/json',
            // Let non-2xx through so push() can read a structured error body
            // instead of losing it inside an exception.
            validateStatus: (status) => status != null && status < 500,
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = tokenProvider?.call();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;

  /// Supplied by the auth service; read per request so a token refresh takes
  /// effect without rebuilding the client.
  final String? Function()? tokenProvider;

  /// Called when the server rejects the token.
  ///
  /// It does **not** mean sign the user out. The shop's records are on this
  /// device and are still theirs to read and add to; only sending them stops
  /// until they sign in again.
  final void Function()? onUnauthorized;

  String get baseUrl => _dio.options.baseUrl;
  set baseUrl(String value) => _dio.options.baseUrl = value;

  bool get isConfigured => _dio.options.baseUrl.isNotEmpty;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    return _guard(() => _dio.get<dynamic>(path, queryParameters: query));
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
  }) async {
    return _guard(() => _dio.post<dynamic>(path, data: body));
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Object? body,
  }) async {
    return _guard(() => _dio.patch<dynamic>(path, data: body));
  }

  Future<Map<String, dynamic>> _guard(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final response = await request();
      final status = response.statusCode ?? 0;
      if (status == 401) onUnauthorized?.call();
      if (status >= 400) {
        throw NetworkException(
          _messageFrom(response.data) ?? 'Request failed ($status)',
          statusCode: status,
        );
      }
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      if (data is List) return {'rows': data};
      return <String, dynamic>{};
    } on DioException catch (e) {
      throw NetworkException(
        _messageFrom(e.response?.data) ?? e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
        cause: e,
      );
    }
  }

  String? _messageFrom(Object? data) {
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    if (data is Map && data['error'] is String) return data['error'] as String;
    return null;
  }
}
