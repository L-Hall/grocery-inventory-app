import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';

import '../../../core/services/api_service.dart';
import '../models/upload_models.dart';

typedef UploadProgressCallback = void Function(int sentBytes, int totalBytes);

class UploadService {
  final ApiService _apiService;
  final Dio _uploadClient;
  final FirebaseFirestore? _firestore;

  UploadService({
    required ApiService apiService,
    FirebaseFirestore? firestore,
    Dio? uploadClient,
  })  : _apiService = apiService,
        _firestore = firestore,
        _uploadClient = uploadClient ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 60),
              receiveTimeout: const Duration(seconds: 60),
              sendTimeout: const Duration(seconds: 60),
            ));

  Future<UploadReservation> reserveUpload({
    required String filename,
    required String contentType,
    required int sizeBytes,
    required String sourceType,
  }) async {
    final response = await _apiService.requestUploadSlot(
      filename: filename,
      contentType: contentType,
      sizeBytes: sizeBytes,
      sourceType: sourceType,
    );
    return UploadReservation.fromJson(response);
  }

  Future<void> uploadBytes({
    required String uploadUrl,
    required Uint8List bytes,
    required String contentType,
    UploadProgressCallback? onProgress,
  }) async {
    try {
      await _uploadClient.put(
        uploadUrl,
        data: bytes,
        options: Options(
          headers: {
            'Content-Type': contentType,
            'Content-Length': bytes.length,
          },
        ),
        onSendProgress: onProgress,
      );
    } on DioException catch (error) {
      throw UploadException(
        'Failed to upload file: ${error.message ?? error.toString()}',
      );
    }
  }

  Future<UploadQueueResult> queueUpload(String uploadId) async {
    final response = await _apiService.queueUpload(uploadId);
    return UploadQueueResult.fromJson(response);
  }

  Future<UploadMetadata> getUpload(String uploadId) async {
    final response = await _apiService.getUpload(uploadId);
    return UploadMetadata.fromJson(response);
  }

  bool get canWatchUploads => _firestore != null;

  Stream<UploadMetadata> watchUpload({
    required String userId,
    required String uploadId,
  }) {
    if (!canWatchUploads) {
      return Stream.error(
        UploadException('Upload tracking is not available in this mode.'),
      );
    }

    return _firestore!
        .doc('users/$userId/uploads/$uploadId')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? {},
          toFirestore: (data, _) => data,
        )
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            throw UploadException('Upload metadata was deleted.');
          }
          final data = {
            ...snapshot.data()!,
            'id': snapshot.id,
          };
          return UploadMetadata.fromJson(data);
        });
  }
}

class UploadException implements Exception {
  final String message;
  UploadException(this.message);

  @override
  String toString() => message;
}
