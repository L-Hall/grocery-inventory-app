import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/api_constants.dart';
import 'storage_service.dart';

class ApiService {
  late final Dio _dio;
  final StorageService storageService;

  ApiService({required this.storageService}) {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add request interceptor for auth token
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add Firebase Auth token to all requests
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final token = await user.getIdToken();
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // Handle token refresh if needed
        if (error.response?.statusCode == 401) {
          try {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              await user.getIdToken(true); // Force refresh
              // Retry the request
              final newToken = await user.getIdToken();
              error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              final retryResponse = await _dio.fetch(error.requestOptions);
              handler.resolve(retryResponse);
              return;
            }
          } catch (e) {
            // Token refresh failed, let the error through
          }
        }
        handler.next(error);
      },
    ));
  }

  // Inventory endpoints
  Future<List<dynamic>> getInventory({
    String? category,
    String? location,
    bool? lowStockOnly,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (category != null) queryParams['category'] = category;
      if (location != null) queryParams['location'] = location;
      if (lowStockOnly != null) queryParams['lowStockOnly'] = lowStockOnly.toString();
      if (search != null) queryParams['search'] = search;

      final response = await _dio.get(
        '/inventory',
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      if (response.statusCode == 200) {
        return response.data['items'] ?? [];
      } else {
        throw ApiException('Failed to fetch inventory', response.statusCode);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<Map<String, dynamic>> updateInventory({
    required List<Map<String, dynamic>> updates,
  }) async {
    try {
      final response = await _dio.post(
        '/inventory/update',
        data: {'updates': updates},
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw ApiException('Failed to update inventory', response.statusCode);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<Map<String, dynamic>> parseGroceryText({
    required String text,
  }) async {
    try {
      final data = {'text': text};

      final response = await _dio.post(
        '/inventory/parse/text',
        data: data,
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw ApiException('Failed to parse grocery text', response.statusCode);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }
  
  Future<Map<String, dynamic>> parseGroceryImage({
    required String imageBase64,
    String imageType = 'receipt',
  }) async {
    try {
      final data = {
        'image': imageBase64,
        'imageType': imageType,
      };

      final response = await _dio.post(
        '/inventory/parse/image',
        data: data,
        options: Options(
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw ApiException('Failed to parse grocery image', response.statusCode);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<Map<String, dynamic>> applyParsedUpdates({
    required List<Map<String, dynamic>> updates,
  }) async {
    try {
      final response = await _dio.post(
        '/inventory/apply',
        data: {'updates': updates},
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw ApiException('Failed to apply inventory updates', response.statusCode);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<List<dynamic>> getLowStockItems({bool includeOutOfStock = true}) async {
    try {
      final response = await _dio.get(
        '/inventory/low-stock',
        queryParameters: {'includeOutOfStock': includeOutOfStock.toString()},
      );

      if (response.statusCode == 200) {
        return response.data['items'] ?? [];
      } else {
        throw ApiException('Failed to fetch low stock items', response.statusCode);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // Grocery list endpoints
  Future<Map<String, dynamic>> createGroceryList({
    String? name,
    bool fromLowStock = true,
    List<Map<String, dynamic>>? customItems,
  }) async {
    try {
      final data = <String, dynamic>{
        'fromLowStock': fromLowStock,
      };
      
      if (name != null) data['name'] = name;
      if (customItems != null) data['customItems'] = customItems;

      final response = await _dio.post('/grocery-lists', data: data);

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw ApiException('Failed to create grocery list', response.statusCode);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<List<dynamic>> getGroceryLists({String? status}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null) queryParams['status'] = status;

      final response = await _dio.get(
        '/grocery-lists',
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      if (response.statusCode == 200) {
        return response.data['lists'] ?? [];
      } else {
        throw ApiException('Failed to fetch grocery lists', response.statusCode);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<List<dynamic>> getCategories() async {
    try {
      final response = await _dio.get('/categories');

      if (response.statusCode == 200) {
        return response.data['categories'] ?? [];
      } else {
        throw ApiException('Failed to fetch categories', response.statusCode);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<Map<String, dynamic>> initializeUser() async {
    try {
      final response = await _dio.post('/user/initialize');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw ApiException('Failed to initialize user', response.statusCode);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await _dio.get('/health');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw ApiException('Health check failed', response.statusCode);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  ApiException _handleDioException(DioException e) {
    String message = 'Unknown error occurred';
    int? statusCode = e.response?.statusCode;

    if (e.type == DioExceptionType.connectionTimeout) {
      message = 'Connection timeout. Please check your internet connection.';
    } else if (e.type == DioExceptionType.receiveTimeout) {
      message = 'Server took too long to respond. Please try again.';
    } else if (e.type == DioExceptionType.badResponse) {
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data['message'] != null) {
        message = data['message'];
      } else {
        switch (statusCode) {
          case 400:
            message = 'Bad request. Please check your input.';
            break;
          case 401:
            message = 'Authentication failed. Please sign in again.';
            break;
          case 403:
            message = 'Access denied.';
            break;
          case 404:
            message = 'Service not found.';
            break;
          case 500:
            message = 'Server error. Please try again later.';
            break;
          default:
            message = 'Request failed with status $statusCode';
        }
      }
    } else if (e.type == DioExceptionType.cancel) {
      message = 'Request was cancelled.';
    } else if (e.error is SocketException) {
      message = 'No internet connection available.';
    }

    return ApiException(message, statusCode);
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
