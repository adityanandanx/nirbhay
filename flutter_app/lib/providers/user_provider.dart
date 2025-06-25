import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/user_data.dart';
import '../services/user_service.dart';
import '../services/user_data_service.dart';

// User Service Provider
final userServiceProvider = Provider<UserService>((ref) => UserService());

// User Data Service Provider
final userDataServiceProvider = Provider<UserDataService>(
  (ref) => UserDataService(),
);

// User Data Provider - provides the current user's data from Firestore
final userDataProvider = FutureProvider<UserModel?>((ref) async {
  final userService = ref.watch(userServiceProvider);

  try {
    final auth = FirebaseAuth.instance;
    final User? currentUser = auth.currentUser;

    if (currentUser == null) {
      return null;
    }

    // Check if the user exists in Firestore
    final userData = await userService.getUserData(currentUser.uid);

    if (userData != null) {
      return UserModel.fromFirestore(userData, currentUser.uid);
    }

    // If the user doesn't exist in Firestore, create a new entry
    await userService.saveUserData(
      uid: currentUser.uid,
      email: currentUser.email ?? '',
      displayName: currentUser.displayName,
      phoneNumber: currentUser.phoneNumber,
      photoURL: currentUser.photoURL,
    );

    // Get the newly created user data
    final newUserData = await userService.getUserData(currentUser.uid);

    if (newUserData != null) {
      return UserModel.fromFirestore(newUserData, currentUser.uid);
    }

    return null;
  } catch (e) {
    throw e;
  }
});

// Update User Data Provider
final updateUserDataProvider =
    Provider.family<Future<void> Function(Map<String, dynamic>), String>(
      (ref, uid) => (Map<String, dynamic> data) async {
        final userService = ref.watch(userServiceProvider);

        await userService.updateUserData(
          uid: uid,
          displayName: data['displayName'] as String?,
          phoneNumber: data['phoneNumber'] as String?,
          photoURL: data['photoURL'] as String?,
        );

        // Refresh user data
        final _ = ref.refresh(userDataProvider);
      },
    );

// Provider for the extended user data from Firestore
final extendedUserDataProvider = FutureProvider<UserData?>((ref) async {
  final userDataService = ref.watch(userDataServiceProvider);
  try {
    return await userDataService.getCurrentUserData();
  } catch (e) {
    throw e;
  }
});

// Stream provider for realtime user data updates
final userDataStreamProvider = StreamProvider<UserData?>((ref) {
  final userDataService = ref.watch(userDataServiceProvider);
  return userDataService.currentUserDataStream();
});
