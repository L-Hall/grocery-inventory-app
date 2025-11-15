import 'package:cloud_firestore/cloud_firestore.dart';

enum UploadStatus {
  awaitingUpload,
  queued,
  processing,
  completed,
  failed;

  static UploadStatus fromString(String? value) {
    switch (value) {
      case 'queued':
        return UploadStatus.queued;
      case 'processing':
        return UploadStatus.processing;
      case 'completed':
        return UploadStatus.completed;
      case 'failed':
        return UploadStatus.failed;
      case 'awaiting_upload':
      default:
        return UploadStatus.awaitingUpload;
    }
  }
}

enum UploadJobStatus {
  queued,
  received,
  awaitingParser,
  completed,
  failed;

  static UploadJobStatus fromString(String? value) {
    switch (value) {
      case 'received':
        return UploadJobStatus.received;
      case 'awaiting_parser':
        return UploadJobStatus.awaitingParser;
      case 'completed':
        return UploadJobStatus.completed;
      case 'failed':
        return UploadJobStatus.failed;
      case 'queued':
      default:
        return UploadJobStatus.queued;
    }
  }
}

class UploadReservation {
  final String uploadId;
  final String uploadUrl;
  final DateTime? uploadUrlExpiresAt;
  final String storagePath;
  final String bucket;
  final UploadStatus status;

  UploadReservation({
    required this.uploadId,
    required this.uploadUrl,
    required this.storagePath,
    required this.bucket,
    required this.status,
    this.uploadUrlExpiresAt,
  });

  factory UploadReservation.fromJson(Map<String, dynamic> json) {
    return UploadReservation(
      uploadId: json['uploadId'] as String? ?? '',
      uploadUrl: json['uploadUrl'] as String? ?? '',
      storagePath: json['storagePath'] as String? ?? '',
      bucket: json['bucket'] as String? ?? '',
      uploadUrlExpiresAt: _parseTimestamp(json['uploadUrlExpiresAt']),
      status: UploadStatus.fromString(json['status'] as String?),
    );
  }
}

class UploadMetadata {
  final String id;
  final String filename;
  final String? originalFilename;
  final String contentType;
  final int? sizeBytes;
  final String storagePath;
  final String bucket;
  final String? sourceType;
  final UploadStatus status;
  final String? lastError;
  final String? processingJobId;
  final String? ingestionJobId;
  final String? processingStage;
  final String? textPreview;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UploadMetadata({
    required this.id,
    required this.filename,
    required this.contentType,
    required this.storagePath,
    required this.bucket,
    required this.status,
    this.originalFilename,
    this.sizeBytes,
    this.sourceType,
    this.lastError,
    this.processingJobId,
    this.ingestionJobId,
    this.processingStage,
    this.textPreview,
    this.createdAt,
    this.updatedAt,
  });

  factory UploadMetadata.fromJson(Map<String, dynamic> json) {
    return UploadMetadata(
      id: json['id'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      originalFilename: json['originalFilename'] as String?,
      contentType: json['contentType'] as String? ?? 'application/octet-stream',
      sizeBytes: _parseInt(json['sizeBytes']),
      storagePath: json['storagePath'] as String? ?? '',
      bucket: json['bucket'] as String? ?? '',
      sourceType: json['sourceType'] as String?,
      status: UploadStatus.fromString(json['status'] as String?),
      lastError: json['lastError'] as String?,
      processingJobId: json['processingJobId'] as String?,
      ingestionJobId: json['ingestionJobId'] as String?,
      processingStage: json['processingStage'] as String?,
      textPreview: json['textPreview'] as String?,
      createdAt: _parseTimestamp(json['createdAt']),
      updatedAt: _parseTimestamp(json['updatedAt']),
    );
  }
}

class UploadQueueResult {
  final String jobId;
  final UploadJobStatus status;

  UploadQueueResult({
    required this.jobId,
    required this.status,
  });

  factory UploadQueueResult.fromJson(Map<String, dynamic> json) {
    return UploadQueueResult(
      jobId: json['jobId'] as String? ?? '',
      status: UploadJobStatus.fromString(json['status'] as String?),
    );
  }
}

DateTime? _parseTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
