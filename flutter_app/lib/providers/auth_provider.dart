import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

// Auth State Model
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  AuthState copyWith({User? user, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  bool get isAuthenticated => user != null;
}

// Auth State Notifier
class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier() : super(const AuthState()) {
    _init();
  }

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  void _init() {
    // Listen to auth state changes
    _firebaseAuth.authStateChanges().listen((user) {
      state = state.copyWith(user: user, isLoading: false);
    });
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    // Normalize the email to avoid case sensitivity issues
    final normalizedEmail = email.trim().toLowerCase();

    try {
      print('Attempting to sign in with email: $normalizedEmail');

      // Skip the email existence check as it might be causing the issue
      // Just attempt to sign in directly
      await _firebaseAuth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      print('Sign in successful for email: $normalizedEmail');
    } on FirebaseAuthException catch (e) {
      // More descriptive error messages for common authentication issues
      String errorMessage;

      switch (e.code) {
        case 'user-not-found':
          // Check Firestore to see if there's a document for this user
          // This is a diagnostic step to verify if the user exists in Firestore but not in Auth
          try {
            final collection = await _userService.checkEmailExists(
              normalizedEmail,
            );
            if (collection) {
              errorMessage =
                  'Your account exists in our database but not in the authentication system. This is an inconsistency. Please contact support or try to sign up again.';
            } else {
              errorMessage =
                  'No account exists with this email. Please sign up first.';
            }
          } catch (_) {
            errorMessage =
                'No account exists with this email. Please sign up first.';
          }
          break;
        case 'wrong-password':
          errorMessage =
              'Incorrect password. Please try again or reset your password.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        case 'user-disabled':
          errorMessage =
              'This account has been disabled. Please contact support.';
          break;
        case 'too-many-requests':
          errorMessage =
              'Too many failed login attempts. Please try again later or reset your password.';
          break;
        default:
          errorMessage =
              e.message ??
              'An error occurred during sign in. Please try again.';
      }

      print('Login error: ${e.code} - ${e.message}');
      state = state.copyWith(isLoading: false, error: errorMessage);
    } catch (e) {
      print('Unexpected login error: ${e.toString()}');
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  Future<void> createUserWithEmailAndPassword(
    String email,
    String password, {
    String? displayName,
    String? phoneNumber,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    // Normalize the email to avoid case sensitivity issues
    final normalizedEmail = email.trim().toLowerCase();

    try {
      print('Attempting to create account with email: $normalizedEmail');

      // Skip the email check as it might be part of the issue
      // Directly create the user account
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        print(
          'User created successfully in Firebase Auth with ID: ${user.uid}',
        );

        // Save user data to Firestore
        await _userService.saveUserData(
          uid: user.uid,
          email: normalizedEmail,
          displayName: displayName,
          phoneNumber: phoneNumber,
          photoURL: user.photoURL,
        );

        print('User data saved to Firestore for ID: ${user.uid}');

        // Update display name in Firebase Auth if provided
        if (displayName != null && displayName.isNotEmpty) {
          await user.updateDisplayName(displayName);
          print('Display name updated in Firebase Auth: $displayName');
        }

        // Force refresh the user to ensure we have the latest data
        await user.reload();
        print('User profile reloaded from Firebase Auth');
      }
    } on FirebaseAuthException catch (e) {
      // More descriptive error messages for common signup issues
      String errorMessage;

      switch (e.code) {
        case 'email-already-in-use':
          errorMessage =
              'This email is already registered. Please sign in instead.';
          break;
        case 'weak-password':
          errorMessage =
              'Password is too weak. Please choose a stronger password.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        case 'operation-not-allowed':
          errorMessage =
              'Email/password accounts are not enabled. Please contact support.';
          break;
        default:
          errorMessage =
              e.message ??
              'An error occurred during registration. Please try again.';
      }

      print('Signup error: ${e.code} - ${e.message}');
      state = state.copyWith(isLoading: false, error: errorMessage);
    } catch (e) {
      print('Unexpected signup error: ${e.toString()}');
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> resetPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      state = state.copyWith(isLoading: false);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  // Handle potential inconsistency between Firestore and Auth
  Future<bool> checkAndFixAccountConsistency(
    String email,
    String password,
  ) async {
    final normalizedEmail = email.trim().toLowerCase();

    try {
      print('Checking account consistency for: $normalizedEmail');

      // Check if user exists in Firestore
      bool existsInFirestore = await _userService.checkEmailExists(
        normalizedEmail,
      );

      if (existsInFirestore) {
        print(
          'User exists in Firestore but sign-in failed. Attempting direct sign in...',
        );

        try {
          // Try signing in directly without preliminary checks
          await _firebaseAuth.signInWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );

          print(
            'Direct sign in worked! User exists and credentials are correct.',
          );
          return true;
        } catch (signInError) {
          print('Direct sign in failed: $signInError');
          return false;
        }
      } else {
        print('User does not exist in Firestore.');
        return false;
      }
    } catch (e) {
      print('Error checking account consistency: $e');
      return false;
    }
  }
}

// Auth Provider
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>(
  (ref) => AuthStateNotifier(),
);
