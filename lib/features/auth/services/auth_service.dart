import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/api_service.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth firebaseAuth;
  final StorageService storageService;
  final ApiService apiService;

  AuthService({
    required this.firebaseAuth,
    required this.storageService,
    required this.apiService,
  });

  // Get current user
  User? get currentUser => firebaseAuth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => firebaseAuth.authStateChanges();

  // Sign in with email and password
  Future<UserModel?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password);

      if (result.user != null) {
        final userModel = UserModel.fromFirebaseUser(result.user!);
        await _saveUserLocally(userModel);

        // Initialize user data in backend if needed
        try {
          await apiService.initializeUser();
        } catch (e) {
          // Don't fail sign in if backend initialization fails
          debugPrint('Backend initialization failed: $e');
        }

        return userModel;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Create account with email and password
  Future<UserModel?> createUserWithEmailAndPassword({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final UserCredential result = await firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);

      if (result.user != null) {
        // Update display name if provided
        if (name != null && name.isNotEmpty) {
          await result.user!.updateDisplayName(name);
        }

        final userModel = UserModel.fromFirebaseUser(result.user!);
        await _saveUserLocally(userModel);

        // Initialize user data in backend
        try {
          await apiService.initializeUser();
        } catch (e) {
          debugPrint('Backend initialization failed: $e');
        }

        return userModel;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with Google (placeholder for future implementation)
  Future<UserModel?> signInWithGoogle() async {
    // TODO: Implement Google Sign In
    throw UnimplementedError('Google Sign In not implemented yet');
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await firebaseAuth.signOut();
      await _clearUserLocally();
    } catch (e) {
      throw Exception('Failed to sign out: ${e.toString()}');
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      final user = firebaseAuth.currentUser;
      if (user != null) {
        await user.delete();
        await _clearUserLocally();
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Update user profile
  Future<void> updateProfile({String? name, String? photoUrl}) async {
    try {
      final user = firebaseAuth.currentUser;
      if (user != null) {
        if (name != null) await user.updateDisplayName(name);
        if (photoUrl != null) await user.updatePhotoURL(photoUrl);

        final userModel = UserModel.fromFirebaseUser(user);
        await _saveUserLocally(userModel);
      }
    } catch (e) {
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  // Get current user as UserModel
  UserModel? getCurrentUserModel() {
    final user = firebaseAuth.currentUser;
    return user != null ? UserModel.fromFirebaseUser(user) : null;
  }

  // Save user data locally
  Future<void> _saveUserLocally(UserModel user) async {
    await storageService.setString(StorageService.keyUserId, user.uid);
    await storageService.setString(
      StorageService.keyUserEmail,
      user.email ?? '',
    );

    if (user.idToken != null) {
      await storageService.setSecureString(
        StorageService.keyAuthToken,
        user.idToken!,
      );
    }
  }

  // Clear local user data
  Future<void> _clearUserLocally() async {
    await storageService.remove(StorageService.keyUserId);
    await storageService.remove(StorageService.keyUserEmail);
    await storageService.removeSecureString(StorageService.keyAuthToken);
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided for that user.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      case 'operation-not-allowed':
        return 'Signing in with Email and Password is not enabled.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return e.message ?? 'An unknown authentication error occurred.';
    }
  }
}
