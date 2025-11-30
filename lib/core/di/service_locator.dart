import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../../features/auth/providers/auth_provider.dart' as auth;
import '../../features/auth/services/auth_service.dart';
import '../../features/inventory/providers/inventory_provider.dart';
import '../../features/inventory/repositories/inventory_repository.dart';
import '../../features/grocery_list/providers/grocery_list_provider.dart';
import '../../features/grocery_list/repositories/grocery_list_repository.dart';
import '../../features/grocery_list/services/ingestion_job_service.dart';
import '../../features/onboarding/providers/onboarding_provider.dart';
import '../../features/analytics/services/agent_metrics_service.dart';
import '../../features/uploads/services/upload_service.dart';
import '../theme/theme_provider.dart';

final GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // External dependencies
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);

  getIt.registerSingleton<FirebaseAuth>(FirebaseAuth.instance);
  getIt.registerSingleton<FirebaseFirestore>(FirebaseFirestore.instance);

  // Core services
  getIt.registerSingleton<StorageService>(
    StorageService(prefs: getIt<SharedPreferences>()),
  );
  getIt.registerSingleton<ThemeModeProvider>(
    ThemeModeProvider(getIt<StorageService>()),
  );

  getIt.registerSingleton<ApiService>(
    ApiService(storageService: getIt<StorageService>()),
  );
  getIt.registerSingleton<UploadService>(
    UploadService(
      apiService: getIt<ApiService>(),
      firestore: getIt<FirebaseFirestore>(),
    ),
  );
  getIt.registerSingleton<IngestionJobService>(
    IngestionJobService(firestore: getIt<FirebaseFirestore>()),
  );
  getIt.registerSingleton<AgentMetricsService>(
    AgentMetricsService(firestore: getIt<FirebaseFirestore>()),
  );

  // Feature services
  getIt.registerSingleton<AuthService>(
    AuthService(
      firebaseAuth: getIt<FirebaseAuth>(),
      storageService: getIt<StorageService>(),
      apiService: getIt<ApiService>(),
    ),
  );

  // Repositories
  getIt.registerSingleton<InventoryRepository>(
    InventoryRepository(getIt<ApiService>()),
  );

  final groceryRepo = GroceryListRepository(getIt<ApiService>());
  getIt
    ..registerSingleton<GroceryListRepository>(groceryRepo)
    ..registerSingleton<GroceryListDataSource>(groceryRepo);

  // Providers
  getIt.registerFactory<auth.AuthProvider>(
    () => auth.AuthProvider(getIt<AuthService>()),
  );

  getIt.registerFactory<InventoryProvider>(
    () => InventoryProvider(getIt<InventoryRepository>()),
  );

  getIt.registerFactory<GroceryListProvider>(
    () => GroceryListProvider(
      getIt<GroceryListDataSource>(),
      ingestionJobService: getIt<IngestionJobService>(),
      uploadService: getIt<UploadService>(),
      auth: getIt<FirebaseAuth>(),
      storageService: getIt<StorageService>(),
    ),
  );

  getIt.registerFactory<OnboardingProvider>(
    () => OnboardingProvider(getIt<StorageService>()),
  );
}
