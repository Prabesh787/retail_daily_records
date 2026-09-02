/// Base for everything the app throws deliberately, so a `catch (e)` in a
/// controller can tell a real failure from a programming error.
class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.cause});
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause, this.statusCode});

  final int? statusCode;

  /// Timeouts and 5xx are worth retrying; a 400 means the payload is wrong and
  /// retrying it forever would block the whole sync queue.
  bool get isRetryable =>
      statusCode == null || statusCode! >= 500 || statusCode == 408;
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}

class SyncException extends AppException {
  const SyncException(super.message, {super.cause});
}
