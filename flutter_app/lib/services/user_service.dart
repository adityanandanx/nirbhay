import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference
  CollectionReference get _users => _firestore.collection('users');

  // Save user data to Firestore
  Future<void> saveUserData({
    required String uid,
    required String email,
    String? displayName,
    String? phoneNumber,
    String? photoURL,
  }) async {
    try {
      await _users.doc(uid).set({
        'email': email,
        'displayName': displayName ?? '',
        'phoneNumber': phoneNumber ?? '',
        'photoURL': photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  // Update user data
  Future<void> updateUserData({
    required String uid,
    String? displayName,
    String? phoneNumber,
    String? photoURL,
  }) async {
    try {
      await _users.doc(uid).update({
        if (displayName != null) 'displayName': displayName,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (photoURL != null) 'photoURL': photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _users.doc(uid).get();
      return doc.exists ? doc.data() as Map<String, dynamic> : null;
    } catch (e) {
      rethrow;
    }
  }

  // Check if user exists in Firestore
  Future<bool> userExists(String uid) async {
    try {
      DocumentSnapshot doc = await _users.doc(uid).get();
      return doc.exists;
    } catch (e) {
      rethrow;
    }
  }

  // Get current user data
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      return await getUserData(user.uid);
    }
    return null;
  }

  // Save additional user information
  Future<void> saveUserDetails({
    required String uid,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      if (additionalData != null) {
        additionalData['updatedAt'] = FieldValue.serverTimestamp();
        await _users.doc(uid).update(additionalData);
      }
    } catch (e) {
      rethrow;
    }
  }

  // Check if an email exists in Firestore
  Future<bool> checkEmailExists(String email) async {
    try {
      print('Checking if email exists in Firestore: $email');
      final querySnapshot =
          await _firestore
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

      final exists = querySnapshot.docs.isNotEmpty;
      print('Email exists in Firestore: $exists');

      if (exists) {
        // For debugging: print document IDs that match this email
        for (var doc in querySnapshot.docs) {
          print('Found document ID: ${doc.id} with email: $email');
        }
      }

      return exists;
    } catch (e) {
      print('Error checking if email exists: $e');
      rethrow;
    }
  }
}
