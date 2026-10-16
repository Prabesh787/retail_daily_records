import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';

/// The one door to the server.
///
/// The backend answers with exactly two envelopes:
///
///     { success: true,  message, data, meta? }
///     { success: false, message, code, errors: [] }
///
/// Callers only ever want `data` (and `meta` when paging), so unwrapping
/// happens once here and a failure becomes a typed exception rather than a
/// status code every caller has to interpret. This mirrors the web app's
/// `lib/api/http.js` deliberately — the two clients talk to the same API, and a
/// difference between them is a bug waiting for whoever reads only one.
class ApiClient {
  ApiClient({
    String? baseUrl,
    this.tokenProvider,
    this.onUnauthorized,
    HttpClientAdapter? adapter,
  }) : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? '',
            // Generous, because the shop is on a phone on mobile data and a
            // request that gives up at three seconds is a bill the shopkeeper
            // has to key in twice.
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
            contentType: 'application/json',
            // Non-2xx arrives as a response rather than an exception, so the
            // server's own message survives instead of being lost inside Dio's.
            validateStatus: (status) => status != null && status < 500,
          ),
        ) {
    // The one seam a test uses. Swapping the transport rather than the client
    // means a screen test still runs every line below — the envelope
    // unwrapping, the error mapping, the auth header — instead of a stand-in
    // that agrees with itself.
    if (adapter != null) _dio.httpClientAdapter = adapter;

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

  /// Supplied by the auth service and read per request, so a token that changed
  /// since the client was built takes effect without rebuilding it.
  final String? Function()? tokenProvider;

  /// Called when the server rejects the token.
  ///
  /// The app is online-only, so a rejected token means the records cannot be
  /// read at all: this ends the session and returns to the front door.
  final void Function()? onUnauthorized;

  String get baseUrl => _dio.options.baseUrl;

  /// False in a build with no `API_BASE_URL`. That is a misconfigured build
  /// rather than a mode — there is nothing for the app to show without one.
  bool get isConfigured => _dio.options.baseUrl.isNotEmpty;

  Future<ApiResponse> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: _clean(query)));

  Future<ApiResponse> post(String path, {Object? body}) =>
      _send(() => _dio.post<dynamic>(path, data: body));

  Future<ApiResponse> patch(String path, {Object? body}) =>
      _send(() => _dio.patch<dynamic>(path, data: body));

  Future<ApiResponse> delete(String path) =>
      _send(() => _dio.delete<dynamic>(path));

  /// Drops empty parameters rather than sending them.
  ///
  /// A query string cannot say "absent" and "empty" differently, and a cleared
  /// search field should not travel at all rather than travel as nothing.
  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;

    final cleaned = <String, dynamic>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      cleaned[entry.key] = value;
    }
    return cleaned.isEmpty ? null : cleaned;
  }

  Future<ApiResponse> _send(Future<Response<dynamic>> Function() request) async {
    if (!isConfigured) {
      throw const NetworkException(
        'This build has no server address set. Rebuild with API_BASE_URL '
        'pointing at the shop server.',
      );
    }

    final Response<dynamic> response;
    try {
      response = await request();
    } on DioException catch (e) {
      throw NetworkException(_transportMessage(e), cause: e);
    }

    final status = response.statusCode ?? 0;
    final payload = response.data;
    final body = payload is Map<String, dynamic> ? payload : null;

    // The session is gone. Ended once, here, rather than letting every open
    // screen fail on its own and leave the user guessing why.
    if (status == 401) onUnauthorized?.call();

    if (status >= 400 || body?['success'] == false) {
      throw _failure(status, body);
    }

    return ApiResponse(
      data: body == null ? payload : body['data'],
      meta: body?['meta'] is Map<String, dynamic>
          ? body!['meta'] as Map<String, dynamic>
          : null,
    );
  }

  /// Turns the server's error envelope into the exception a controller already
  /// knows how to show.
  ///
  /// The split is what matters: a 4xx carries a message written for a person —
  /// "Bill 4521 is already recorded for this supplier" — and belongs beside the
  /// field that caused it, while anything else is a failure of the connection
  /// and belongs in the screen's error state.
  AppException _failure(int status, Map<String, dynamic>? body) {
    final raw = (body?['message'] as String?)?.trim();
    final message = (raw == null || raw.isEmpty) ? null : raw;

    if (status == 401) {
      return NetworkException(
        message ?? 'Your session has ended. Please sign in again.',
        statusCode: status,
      );
    }

    if (status >= 400 && status < 500) {
      return ValidationException(
        message ?? 'That could not be saved.',
        fieldErrors: _fieldErrors(body?['errors']),
        statusCode: status,
      );
    }

    return NetworkException(
      message ?? 'Request failed ($status)',
      statusCode: status,
    );
  }

  /// `[{ field: "body.billNo", message: "…" }]` keyed by the name the form
  /// knows, with the prefix the validator adds stripped off.
  Map<String, String> _fieldErrors(Object? errors) {
    if (errors is! List) return const {};

    final result = <String, String>{};
    for (final entry in errors) {
      if (entry is! Map) continue;
      final field = entry['field']?.toString();
      final message = entry['message']?.toString();
      if (field == null || message == null) continue;
      result[field.replaceFirst(RegExp(r'^(body|query|params)\.'), '')] =
          message;
    }
    return result;
  }

  String _transportMessage(DioException e) => switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'The server took too long to answer. Check your connection and try '
              'again.',
        DioExceptionType.connectionError =>
          'Cannot reach the server. Check your connection.',
        _ => e.message ?? 'Cannot reach the server.',
      };
}

/// One answer from the API: the payload, and the paging figures beside it.
class ApiResponse {
  const ApiResponse({this.data, this.meta});

  final Object? data;

  /// Present on list endpoints: `{ page, limit, total, totalPages }`.
  final Map<String, dynamic>? meta;

  Map<String, dynamic> get object =>
      data is Map<String, dynamic> ? data as Map<String, dynamic> : const {};

  List<Map<String, dynamic>> get rows => data is List
      ? (data as List).whereType<Map<String, dynamic>>().toList()
      : const [];

  /// How many rows exist in total, not only on this page.
  int get total => (meta?['total'] as num?)?.toInt() ?? rows.length;
}
