import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/grocery_list.dart';
import '../models/ingestion_job.dart';
import '../models/parsed_item.dart';
import '../repositories/grocery_list_repository.dart';
import '../services/ingestion_job_service.dart';
import '../../inventory/models/inventory_item.dart';
import '../../uploads/models/upload_models.dart';
import '../../uploads/services/upload_service.dart';
import '../../../core/services/storage_service.dart';

class GroceryListProvider with ChangeNotifier {
  final GroceryListDataSource _repository;
  final IngestionJobService _ingestionJobService;
  final UploadService? _uploadService;
  final FirebaseAuth? _auth;
  final StorageService? _storage;
  StreamSubscription<IngestionJob>? _ingestionJobSubscription;
  StreamSubscription<UploadMetadata>? _uploadSubscription;
  bool _ingestionTrackingLimited = false;

  List<GroceryList> _groceryLists = [];
  ParseResult? _lastParseResult;
  bool _isLoading = false;
  bool _isParsing = false;
  bool _isUploading = false;
  String? _error;
  String _currentInputText = '';
  IngestionJob? _activeIngestionJob;
  UploadMetadata? _activeUpload;
  double _uploadProgress = 0;

  GroceryListProvider(
    this._repository, {
    IngestionJobService? ingestionJobService,
    UploadService? uploadService,
    FirebaseAuth? auth,
    StorageService? storageService,
  }) : _ingestionJobService =
           ingestionJobService ?? const IngestionJobService(),
       _uploadService = uploadService,
       _auth =
           auth ?? (Firebase.apps.isNotEmpty ? FirebaseAuth.instance : null),
       _storage = storageService;

  // Getters
  List<GroceryList> get groceryLists => _groceryLists;
  List<GroceryList> get activeLists => _groceryLists
      .where((list) => list.status == GroceryListStatus.active)
      .toList();
  List<GroceryList> get completedLists => _groceryLists
      .where((list) => list.status == GroceryListStatus.completed)
      .toList();

  ParseResult? get lastParseResult => _lastParseResult;
  bool get isLoading => _isLoading;
  bool get isParsing => _isParsing;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get hasParseResult => _lastParseResult != null;
  String get currentInputText => _currentInputText;
  IngestionJob? get activeIngestionJob => _activeIngestionJob;
  bool get hasActiveIngestionJob => _activeIngestionJob != null;
  bool get supportsAsyncIngestion => _ingestionJobService.isAvailable;
  bool get supportsUploadIngestion =>
      supportsAsyncIngestion && (_uploadService?.canWatchUploads ?? false);
  bool get ingestionTrackingLimited => _ingestionTrackingLimited;
  UploadMetadata? get activeUpload => _activeUpload;
  bool get hasActiveUpload => _activeUpload != null;
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  bool get isProcessing => _isParsing || _isUploading;

  // Parse result convenience getters
  List<ParsedItem> get parsedItems => _lastParseResult?.items ?? [];
  bool get hasLowConfidenceItems =>
      _lastParseResult?.hasLowConfidenceItems ?? false;
  bool get usedFallbackParser => _lastParseResult?.usedFallback ?? false;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setParsing(bool parsing) {
    _isParsing = parsing;
    notifyListeners();
  }

  void _setUploading(bool uploading) {
    _isUploading = uploading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  Map<String, dynamic> _buildParsingMetadata({
    Map<String, dynamic>? extra,
  }) {
    final unitSystem =
        _storage?.getString(StorageService.keyUnitSystem) ?? 'metric';
    return {
      'unitSystem': unitSystem,
      if (extra != null) ...extra,
    };
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearParseResult() {
    _lastParseResult = null;
    _currentInputText = '';
    notifyListeners();
  }

  // Load grocery lists
  Future<void> loadGroceryLists({bool refresh = false}) async {
    try {
      if (refresh || _groceryLists.isEmpty) {
        _setLoading(true);
        _setError(null);
      }

      final lists = await _repository.getGroceryLists();
      _groceryLists = lists;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load grocery lists: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Parse natural language text
  Future<bool> parseGroceryText({required String text}) async {
    try {
      _setParsing(true);
      _setError(null);
      _currentInputText = text;

      final result = await _repository.parseGroceryText(
        text: text,
        metadata: _buildParsingMetadata(),
      );

      _lastParseResult = result;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to parse grocery text: $e');
      return false;
    } finally {
      _setParsing(false);
    }
  }

  Future<bool> submitIngestionJob({
    required String text,
    Map<String, dynamic>? metadata,
  }) async {
    if (!supportsAsyncIngestion) {
      return parseGroceryText(text: text);
    }

    try {
      _setParsing(true);
      _setError(null);
      _currentInputText = text;

      final handle = await _repository.startIngestionJob(
        text: text,
        metadata: _buildParsingMetadata(extra: metadata),
      );

      _activeIngestionJob = IngestionJob.initial(
        id: handle.jobId,
        jobPath: handle.jobPath,
        status: handle.status,
        text: text,
      );
      _ingestionTrackingLimited = false;
      notifyListeners();

      _listenToIngestionJob(handle.jobPath);
      return true;
    } catch (e) {
      _setParsing(false);
      _setError('Failed to start background processing: $e');
      return false;
    }
  }

  Future<bool> submitUploadForIngestion({
    required Uint8List bytes,
    required String filename,
    required String contentType,
    required String sourceType,
  }) async {
    final uploadService = _uploadService;
    final userId = _auth?.currentUser?.uid;

    if (uploadService == null || !uploadService.canWatchUploads) {
      _setError('Uploads are not supported in this environment.');
      return false;
    }

    if (userId == null) {
      _setError('Please sign in again before uploading files.');
      return false;
    }

    try {
      _setParsing(true);
      _setError(null);
      _setUploading(true);
      _uploadProgress = 0;
      _currentInputText = '[Upload: $filename]';

      final reservation = await uploadService.reserveUpload(
        filename: filename,
        contentType: contentType,
        sizeBytes: bytes.length,
        sourceType: sourceType,
      );

      await uploadService.uploadBytes(
        uploadUrl: reservation.uploadUrl,
        bytes: bytes,
        contentType: contentType,
        onProgress: (sent, total) {
          if (total > 0) {
            _uploadProgress = sent / total;
            notifyListeners();
          }
        },
      );

      await uploadService.queueUpload(reservation.uploadId);

      _setParsing(false);
      _setUploading(false);
      _listenToUpload(userId, reservation.uploadId);
      return true;
    } catch (e) {
      _setParsing(false);
      _setUploading(false);
      _uploadProgress = 0;
      _setError('Failed to process upload: $e');
      return false;
    }
  }

  // Parse image (receipt or grocery list photo)
  Future<bool> parseGroceryImage({
    required String imageBase64,
    String imageType = 'receipt',
  }) async {
    try {
      _setParsing(true);
      _setError(null);
      _currentInputText = '[Image: $imageType]';

      final result = await _repository.parseGroceryImage(
        imageBase64: imageBase64,
        imageType: imageType,
      );

      _lastParseResult = result;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to process image: $e');
      return false;
    } finally {
      _setParsing(false);
    }
  }

  // Apply parsed items to inventory
  Future<bool> applyParsedItems({List<ParsedItem>? customItems}) async {
    try {
      _setLoading(true);
      _setError(null);

      final itemsToApply = customItems ?? parsedItems;
      if (itemsToApply.isEmpty) {
        _setError('No items to apply');
        return false;
      }

      await _repository.applyParsedItemsToInventory(itemsToApply);

      // Clear parse result after successful application
      clearParseResult();

      return true;
    } catch (e) {
      final message = e is GroceryListRepositoryException
          ? e.message
          : 'Failed to apply changes to inventory: $e';
      _setError(message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update a parsed item (for editing in review screen)
  void updateParsedItem(int index, ParsedItem updatedItem) {
    if (_lastParseResult != null && index < _lastParseResult!.items.length) {
      final updatedItems = List<ParsedItem>.from(_lastParseResult!.items);
      updatedItems[index] = updatedItem.copyWith(isEdited: true);

      _lastParseResult = _lastParseResult!.copyWith(items: updatedItems);
      notifyListeners();
    }
  }

  // Remove a parsed item
  void removeParsedItem(int index) {
    if (_lastParseResult != null && index < _lastParseResult!.items.length) {
      final updatedItems = List<ParsedItem>.from(_lastParseResult!.items);
      updatedItems.removeAt(index);

      _lastParseResult = _lastParseResult!.copyWith(items: updatedItems);
      notifyListeners();
    }
  }

  // Add a new parsed item
  void addParsedItem(ParsedItem item) {
    if (_lastParseResult != null) {
      final updatedItems = List<ParsedItem>.from(_lastParseResult!.items);
      updatedItems.add(item.copyWith(isEdited: true, confidence: 1.0));

      _lastParseResult = _lastParseResult!.copyWith(items: updatedItems);
      notifyListeners();
    }
  }

  // Create grocery list from low stock items
  Future<bool> createGroceryListFromLowStock({String? name}) async {
    try {
      _setLoading(true);
      _setError(null);

      final list = await _repository.createGroceryListFromLowStock(name: name);
      _groceryLists.add(list);
      notifyListeners();

      return true;
    } catch (e) {
      _setError('Failed to create grocery list: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Create custom grocery list
  Future<bool> createCustomGroceryList({
    required String name,
    required List<GroceryListItemTemplate> items,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final list = await _repository.createCustomGroceryList(
        name: name,
        items: items,
      );
      _groceryLists.add(list);
      notifyListeners();

      return true;
    } catch (e) {
      _setError('Failed to create grocery list: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Get item suggestions for autocomplete
  Future<List<String>> getItemSuggestions({String? query}) async {
    return _repository.getItemSuggestions(query: query);
  }

  // Validate parsed items
  List<String> validateParsedItems({List<ParsedItem>? customItems}) {
    final itemsToValidate = customItems ?? parsedItems;
    return _repository.validateParsedItems(itemsToValidate);
  }

  // Get parsing tips for users
  List<String> getParsingTips() {
    return _repository.getParsingTips();
  }

  // Parse with common format enhancements
  Future<bool> parseWithEnhancements({required String text}) async {
    try {
      _setParsing(true);
      _setError(null);
      _currentInputText = text;

      final result = await _repository.parseCommonFormats(text);
      _lastParseResult = result;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to parse grocery text: $e');
      return false;
    } finally {
      _setParsing(false);
    }
  }

  // Get recently parsed items for quick reuse
  List<ParsedItem> get recentlyParsedItems {
    // This could be expanded to store recent items in local storage
    return parsedItems;
  }

  // Statistics about current parse result
  Map<String, int> get parseStatistics {
    if (_lastParseResult == null) return {};

    final stats = <String, int>{};
    final items = _lastParseResult!.items;

    stats['total'] = items.length;
    stats['high_confidence'] = items
        .where((item) => item.confidenceLevel == ConfidenceLevel.high)
        .length;
    stats['medium_confidence'] = items
        .where((item) => item.confidenceLevel == ConfidenceLevel.medium)
        .length;
    stats['low_confidence'] = items
        .where((item) => item.confidenceLevel == ConfidenceLevel.low)
        .length;
    stats['edited'] = items.where((item) => item.isEdited).length;

    // Action counts
    stats['add_actions'] = items
        .where((item) => item.action == UpdateAction.add)
        .length;
    stats['subtract_actions'] = items
        .where((item) => item.action == UpdateAction.subtract)
        .length;
    stats['set_actions'] = items
        .where((item) => item.action == UpdateAction.set)
        .length;

    return stats;
  }

  // Refresh all data
  Future<void> refresh() async {
    await loadGroceryLists(refresh: true);
  }

  // Set current input text (for preserving state)
  void setCurrentInputText(String text) {
    _currentInputText = text;
    notifyListeners();
  }

  // Check if there are any changes that need to be applied
  bool get hasUnappliedChanges =>
      _lastParseResult != null && parsedItems.isNotEmpty;

  // Get summary of what will be changed
  String getChangesSummary() {
    if (!hasUnappliedChanges) return '';

    final stats = parseStatistics;
    final parts = <String>[];

    if (stats['add_actions']! > 0) {
      parts.add('${stats['add_actions']} items will be added');
    }
    if (stats['subtract_actions']! > 0) {
      parts.add('${stats['subtract_actions']} items will be used/subtracted');
    }
    if (stats['set_actions']! > 0) {
      parts.add(
        '${stats['set_actions']} items will be set to specific quantities',
      );
    }

    return parts.join(', ');
  }

  void dismissIngestionJobStatus() {
    if (_activeIngestionJob?.isTerminal ?? false) {
      _ingestionJobSubscription?.cancel();
      _ingestionJobSubscription = null;
      _activeIngestionJob = null;
      notifyListeners();
    }
  }

  void dismissUploadStatus() {
    _uploadSubscription?.cancel();
    _uploadSubscription = null;
    _activeUpload = null;
    _uploadProgress = 0;
    notifyListeners();
  }

  void _listenToIngestionJob(String jobPath) {
    _ingestionJobSubscription?.cancel();
    _ingestionJobSubscription = _ingestionJobService
        .watchJob(jobPath)
        .listen(
          (job) {
            _activeIngestionJob = job;
            _ingestionTrackingLimited = false;
            if (job.isTerminal) {
              _ingestionJobSubscription?.cancel();
              _ingestionJobSubscription = null;
              _setParsing(false);
              if (job.isFailed) {
                _setError(job.lastError ?? 'Background processing failed.');
              } else {
                _currentInputText = '';
              }
            }
            notifyListeners();
          },
          onError: (error) {
            _setParsing(false);
            final message = error.toString();
            final permissionDenied = message.contains('permission-denied') ||
                message.toLowerCase().contains('insufficient permissions');

            if (permissionDenied) {
              // Gracefully degrade: keep background processing running but
              // inform the UI that tracking is limited.
              _activeIngestionJob = _activeIngestionJob?.copyWith(
                status: IngestionJobStatus.processing,
                lastError:
                    'Processing in the background. Updates may take a moment to appear.',
              );
              _ingestionTrackingLimited = true;
              notifyListeners();
              return;
            }

            _setError('Unable to track ingestion job: $message');
          },
        );
  }

  void _listenToUpload(String userId, String uploadId) {
    final uploadService = _uploadService;
    if (uploadService == null) {
      return;
    }

    _uploadSubscription?.cancel();
    _uploadSubscription = uploadService
        .watchUpload(userId: userId, uploadId: uploadId)
        .listen(
          (upload) {
            _activeUpload = upload;
            notifyListeners();

            if (upload.status == UploadStatus.failed) {
              _setError(upload.lastError ?? 'Upload failed.');
              return;
            }

            final ingestionJobId = upload.ingestionJobId;
            if (ingestionJobId != null && ingestionJobId.isNotEmpty) {
              final jobPath = 'users/$userId/ingestion_jobs/$ingestionJobId';
              final alreadyTracking = _activeIngestionJob?.id == ingestionJobId;
              if (!alreadyTracking) {
                _activeIngestionJob = IngestionJob.initial(
                  id: ingestionJobId,
                  jobPath: jobPath,
                  status: IngestionJobStatus.pending,
                  text: upload.textPreview,
                );
                notifyListeners();
                _listenToIngestionJob(jobPath);
              }
            }
          },
          onError: (error) {
            _setError('Unable to track upload: $error');
          },
        );
  }

  @override
  void dispose() {
    _ingestionJobSubscription?.cancel();
    _uploadSubscription?.cancel();
    super.dispose();
  }
}
