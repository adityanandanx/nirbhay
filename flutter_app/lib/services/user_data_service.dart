import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_data.dart';

class UserDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference
  CollectionReference get _users => _firestore.collection('users');

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get current user id
  String? get currentUserId => _auth.currentUser?.uid;

  // Get user document reference
  DocumentReference getUserRef(String uid) => _users.doc(uid);

  // Save new user data to Firestore
  Future<void> createUserData(User user) async {
    try {
      final userData = UserData.fromUser(user);

      final userMap = userData.toMap();
      userMap['createdAt'] = FieldValue.serverTimestamp();
      userMap['updatedAt'] = FieldValue.serverTimestamp();

      await _users.doc(user.uid).set(userMap);
    } catch (e) {
      print('Error creating user data: $e');
      rethrow;
    }
  }

  // Get user data from Firestore
  Future<UserData?> getUserData(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      if (doc.exists) {
        return UserData.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      rethrow;
    }
  }

  // Get current user data
  Future<UserData?> getCurrentUserData() async {
    final user = currentUser;
    if (user != null) {
      return getUserData(user.uid);
    }
    return null;
  }

  // Update user data
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _users.doc(uid).update(data);
    } catch (e) {
      print('Error updating user data: $e');
      rethrow;
    }
  }

  // Update current user data
  Future<void> updateCurrentUserData(Map<String, dynamic> data) async {
    final uid = currentUserId;
    if (uid != null) {
      await updateUserData(uid, data);
    }
  }

  // Update primary emergency contact
  Future<void> updatePrimaryEmergencyContact(
    String uid,
    String name,
    String phone,
  ) async {
    try {
      await _users.doc(uid).update({
        'emergencyContactName': name,
        'emergencyContactPhone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating primary emergency contact: $e');
      rethrow;
    }
  }

  // Update user address
  Future<void> updateAddress(String uid, String address) async {
    try {
      await _users.doc(uid).update({
        'address': address,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating address: $e');
      rethrow;
    }
  }

  // Update safety stats
  Future<void> updateSafetyStats(String uid, Map<String, dynamic> stats) async {
    try {
      await _users.doc(uid).update({
        'safetyStats': stats,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating safety stats: $e');
      rethrow;
    }
  }

  // Update user preferences
  Future<void> updatePreferences(
    String uid,
    Map<String, dynamic> preferences,
  ) async {
    try {
      await _users.doc(uid).update({
        'preferences': preferences,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating preferences: $e');
      rethrow;
    }
  }

  // Check if user exists
  Future<bool> userExists(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      return doc.exists;
    } catch (e) {
      print('Error checking if user exists: $e');
      rethrow;
    }
  }

  // Stream of user data updates
  Stream<UserData?> userDataStream(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return UserData.fromFirestore(doc);
      }
      return null;
    });
  }

  // Stream of current user data updates
  Stream<UserData?> currentUserDataStream() {
    final uid = currentUserId;
    if (uid != null) {
      return userDataStream(uid);
    }
    return Stream.value(null);
  }

  // Delete user data
  Future<void> deleteUserData(String uid) async {
    try {
      await _users.doc(uid).delete();
    } catch (e) {
      print('Error deleting user data: $e');
      rethrow;
    }
  }

  // Get emergency contacts for a user
  Future<List<Map<String, dynamic>>> getEmergencyContacts(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        return List<Map<String, dynamic>>.from(
          data['emergencyContacts'] as List<dynamic>? ?? [],
        );
      }
      return [];
    } catch (e) {
      print('Error getting emergency contacts: $e');
      rethrow;
    }
  }

  // Save emergency contacts
  Future<void> saveEmergencyContacts(
    String uid,
    List<Map<String, dynamic>> contacts,
  ) async {
    try {
      await _users.doc(uid).update({
        'emergencyContacts': contacts,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving emergency contacts: $e');
      rethrow;
    }
  }

  // Add an emergency contact
  Future<void> addEmergencyContact(
    String uid,
    Map<String, dynamic> contact,
  ) async {
    try {
      // Get current contacts
      final contacts = await getEmergencyContacts(uid);

      // Add new contact
      contacts.add(contact);

      // Save updated contacts
      await saveEmergencyContacts(uid, contacts);
    } catch (e) {
      print('Error adding emergency contact: $e');
      rethrow;
    }
  }

  // Update an emergency contact
  Future<void> updateEmergencyContact(
    String uid,
    String contactId,
    Map<String, dynamic> updatedContact,
  ) async {
    try {
      // Get current contacts
      final contacts = await getEmergencyContacts(uid);

      // Find and update the contact
      final index = contacts.indexWhere((c) => c['id'] == contactId);
      if (index != -1) {
        contacts[index] = updatedContact;

        // Save updated contacts
        await saveEmergencyContacts(uid, contacts);
      }
    } catch (e) {
      print('Error updating emergency contact: $e');
      rethrow;
    }
  }

  // Remove an emergency contact
  Future<void> removeEmergencyContact(String uid, String contactId) async {
    try {
      // Get current contacts
      final contacts = await getEmergencyContacts(uid);

      // Remove the contact
      contacts.removeWhere((c) => c['id'] == contactId);

      // Save updated contacts
      await saveEmergencyContacts(uid, contacts);
    } catch (e) {
      print('Error removing emergency contact: $e');
      rethrow;
    }
  }
}
