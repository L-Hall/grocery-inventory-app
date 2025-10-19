class ApiConstants {
  // Base URL for the API - update this with your Firebase Functions URL
  static const String baseUrl = 'https://us-central1-helical-button-461921-v6.cloudfunctions.net/api';
  
  // Local development URL (for testing with Firebase emulators)
  static const String localBaseUrl = 'http://localhost:5001/helical-button-461921-v6/us-central1/api';
  
  // Endpoints
  static const String inventory = '/inventory';
  static const String inventoryUpdate = '/inventory/update';
  static const String inventoryParse = '/inventory/parse';
  static const String inventoryLowStock = '/inventory/low-stock';
  static const String groceryLists = '/grocery-lists';
  static const String categories = '/categories';
  static const String userInitialize = '/user/initialize';
  static const String health = '/health';
  
  // Request timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // Pagination
  static const int defaultPageSize = 50;
  static const int maxPageSize = 100;
}