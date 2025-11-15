import 'package:cloud_firestore/cloud_firestore.dart';

enum IngestionJobStatus {
  pending,
  processing,
  completed,
  failed,
}

IngestionJobStatus ingestionJobStatusFromString(String? value) {
  switch (value) {
    case 'completed':
      return IngestionJobStatus.completed;
    case 'processing':
      return IngestionJobStatus.processing;
    case 'failed':
      return IngestionJobStatus.failed;
    case 'pending':
    default:
      return IngestionJobStatus.pending;
  }
}

class IngestionJob {
  final String id;
  final String jobPath;
  final IngestionJobStatus status;
  final String? text;
  final String? resultSummary;
  final String? agentResponse;
  final String? lastError;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const IngestionJob({
    required this.id,
    required this.jobPath,
    required this.status,
    this.text,
    this.resultSummary,
    this.agentResponse,
    this.lastError,
    this.createdAt,
    this.updatedAt,
  });

  bool get isComplete => status == IngestionJobStatus.completed;
  bool get isFailed => status == IngestionJobStatus.failed;
  bool get isTerminal => isComplete || isFailed;

  factory IngestionJob.initial({
    required String id,
    required String jobPath,
    required IngestionJobStatus status,
    String? text,
  }) {
    return IngestionJob(
      id: id,
      jobPath: jobPath,
      status: status,
      text: text,
      createdAt: DateTime.now(),
    );
  }

  factory IngestionJob.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    return IngestionJob(
      id: snapshot.id,
      jobPath: snapshot.reference.path,
      status: ingestionJobStatusFromString(data['status'] as String?),
      text: (data['text'] as String?)?.trim(),
      resultSummary: data['resultSummary'] as String?,
      agentResponse: data['agentResponse'] as String?,
      lastError: data['lastError'] as String?,
      createdAt: _normalizeTimestamp(data['createdAt']),
      updatedAt: _normalizeTimestamp(data['updatedAt']),
    );
  }

  static DateTime? _normalizeTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class IngestionJobHandle {
  final String jobId;
  final String jobPath;
  final IngestionJobStatus status;

  IngestionJobHandle({
    required this.jobId,
    required this.jobPath,
    required this.status,
  });

  factory IngestionJobHandle.fromJson(Map<String, dynamic> json) {
    return IngestionJobHandle(
      jobId: json['jobId'] as String? ?? '',
      jobPath: json['jobPath'] as String? ??
          'users/${json['userId'] ?? 'unknown'}/ingestion_jobs/${json['jobId'] ?? ''}',
      status: ingestionJobStatusFromString(json['status'] as String?),
    );
  }
}
