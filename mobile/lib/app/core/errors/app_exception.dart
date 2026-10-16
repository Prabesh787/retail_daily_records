/// Base for everything the app throws deliberately, so a `catch (e)` in a
/// controller can tell a real failure from a programming error.
class AppException implements Exception {
  const AppException(this.message, {this.cause});

  /// Written for a shopkeeper, not for a log. Screens show it as it is.
  final String message;

  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// The request never got an answer, or got one the app cannot use: no signal,
/// a timeout, a 5xx, an expired session.
///
/// The distinction from [ValidationException] is what the user is told to do.
/// This one means "try again"; the other means "change something first".
class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause, this.statusCode});

  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;
}

/// The server refused the payload and said why in words worth repeating — a
/// duplicate bill number, a cheque with no date, a supplier that still has
/// history against it.
///
/// [fieldErrors] carries the per-field messages when the failure was a
/// validation one, keyed by the field name the form uses, so a form can point
/// at the input that caused it instead of showing one line at the top.
class ValidationException extends AppException {
  const ValidationException(
    super.message, {
    this.fieldErrors = const {},
    this.statusCode,
    super.cause,
  });

  final Map<String, String> fieldErrors;
  final int? statusCode;

  /// The record is gone — deleted on another device, or a stale link.
  bool get isNotFound => statusCode == 404;

  String? errorFor(String field) => fieldErrors[field];
}
