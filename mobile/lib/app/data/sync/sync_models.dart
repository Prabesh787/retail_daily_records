import 'dart:convert';

import '../enums/sync_status.dart';

/// One queued change waiting to reach the backend — a row in the outbox.
///
/// The payload is a JSON snapshot taken at write time rather than a pointer to
/// the current row. If the same bill is edited twice offline the server sees
/// both states in order, and a row deleted locally can still be pushed.
class SyncOperation {
  const SyncOperation({
    required this.queueId,
    required this.entity,
    required this.entityId,
    required this.operation,
    required this.updatedAt,
    required this.payload,
    this.createdAt = 0,
    this.retryCount = 0,
    this.lastError,
  });

  final int queueId;
  final String entity;
  final String entityId;
  final SyncOperationType operation;
  final int updatedAt;
  final Map<String, dynamic> payload;
  final int createdAt;
  final int retryCount;
  final String? lastError;

  /// Wire shape. Kept flat and boring so any backend can consume it.
  Map<String, dynamic> toJson() => {
        'entity': entity,
        'entity_id': entityId,
        'operation': operation.value,
        'updated_at': updatedAt,
        'payload': payload,
      };

  Map<String, dynamic> toMap() => {
        'entity': entity,
        'entity_id': entityId,
        'operation': operation.value,
        'updated_at': updatedAt,
        'payload': jsonEncode(payload),
        'created_at': createdAt,
        'retry_count': retryCount,
        'last_error': lastError,
      };

  factory SyncOperation.fromMap(Map<String, dynamic> map) => SyncOperation(
        queueId: (map['id'] as int?) ?? 0,
        entity: (map['entity'] as String?) ?? '',
        entityId: (map['entity_id'] as String?) ?? '',
        operation: SyncOperationType.fromValue(map['operation'] as String?),
        updatedAt: (map['updated_at'] as int?) ?? 0,
        payload: _decodePayload(map['payload']),
        createdAt: (map['created_at'] as int?) ?? 0,
        retryCount: (map['retry_count'] as int?) ?? 0,
        lastError: map['last_error'] as String?,
      );

  static Map<String, dynamic> _decodePayload(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    }
    return <String, dynamic>{};
  }
}

enum OperationStatus {
  accepted,
  conflict,
  error;

  static OperationStatus fromValue(String? value) => switch (value) {
        'accepted' || 'ok' || 'success' => OperationStatus.accepted,
        'conflict' => OperationStatus.conflict,
        _ => OperationStatus.error,
      };
}

/// The server's verdict on a single pushed operation. A conflict carries the
/// server's current row so the [ConflictResolver] can decide without a
/// second round trip.
class OperationResult {
  const OperationResult({
    required this.entityId,
    required this.status,
    this.serverRow,
    this.message,
    this.retryable = true,
  });

  final String entityId;
  final OperationStatus status;
  final Map<String, dynamic>? serverRow;
  final String? message;
  final bool retryable;

  bool get isAccepted => status == OperationStatus.accepted;

  factory OperationResult.fromJson(Map<String, dynamic> json) =>
      OperationResult(
        entityId: (json['entity_id'] ?? json['id'] ?? '') as String,
        status: OperationStatus.fromValue(json['status'] as String?),
        serverRow: json['server_row'] as Map<String, dynamic>?,
        message: json['message'] as String?,
        retryable: (json['retryable'] as bool?) ?? true,
      );
}

class PushResult {
  const PushResult({this.results = const [], this.serverTime});

  final List<OperationResult> results;
  final int? serverTime;

  int get acceptedCount => results.where((r) => r.isAccepted).length;

  factory PushResult.fromJson(Map<String, dynamic> json) => PushResult(
        results: ((json['results'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(OperationResult.fromJson)
            .toList(),
        serverTime: json['server_time'] as int?,
      );
}

/// One page of server-side changes since a cursor.
///
/// The cursor is opaque to the client — the backend is free to implement it as
/// a timestamp or a sequence number without the app caring.
class PullResult {
  const PullResult({
    this.rows = const [],
    this.nextCursor,
    this.hasMore = false,
    this.serverTime,
  });

  final List<Map<String, dynamic>> rows;
  final String? nextCursor;
  final bool hasMore;
  final int? serverTime;

  bool get isEmpty => rows.isEmpty;

  factory PullResult.fromJson(Map<String, dynamic> json) => PullResult(
        rows: ((json['rows'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(),
        nextCursor: json['next_cursor'] as String?,
        hasMore: (json['has_more'] as bool?) ?? false,
        serverTime: json['server_time'] as int?,
      );
}

/// Outcome of one full push+pull cycle, for the UI and the logs.
class SyncReport {
  const SyncReport({
    this.pushed = 0,
    this.pulled = 0,
    this.conflicts = 0,
    this.failed = 0,
    this.error,
    this.finishedAt,
  });

  final int pushed;
  final int pulled;
  final int conflicts;
  final int failed;
  final String? error;
  final int? finishedAt;

  bool get isSuccess => error == null && failed == 0;

  SyncReport merge(SyncReport other) => SyncReport(
        pushed: pushed + other.pushed,
        pulled: pulled + other.pulled,
        conflicts: conflicts + other.conflicts,
        failed: failed + other.failed,
        error: error ?? other.error,
        finishedAt: other.finishedAt ?? finishedAt,
      );

  @override
  String toString() =>
      'SyncReport(pushed: $pushed, pulled: $pulled, conflicts: $conflicts, '
      'failed: $failed, error: $error)';
}
