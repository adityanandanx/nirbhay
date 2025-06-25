import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// UserData class to store user data in Firestore
/// This model is for storing additional user information
/// beyond what Firebase Auth provides
class UserData {
  final String uid;
  final String email;
  final String displayName;
  final String phoneNumber;
  final String photoURL;
  final String? address;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final bool emailVerified;
  final Map<String, dynamic>? preferences;
  final Map<String, dynamic>? safetyStats;
  final List<Map<String, dynamic>>? emergencyContacts;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  UserData({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.phoneNumber = '',
    this.photoURL = '',
    this.address,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.emailVerified = false,
    this.preferences,
    this.safetyStats,
    this.emergencyContacts,
    this.createdAt,
    this.updatedAt,
  });

  // Factory constructor to create UserData from Firestore document
  factory UserData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Parse emergency contacts if they exist in the document
    List<Map<String, dynamic>>? emergencyContacts;
    if (data['emergencyContacts'] != null) {
      emergencyContacts = List<Map<String, dynamic>>.from(
        data['emergencyContacts'] as List<dynamic>? ?? [],
      );
    }

    return UserData(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      photoURL: data['photoURL'] ?? '',
      address: data['address'],
      emergencyContactName: data['emergencyContactName'],
      emergencyContactPhone: data['emergencyContactPhone'],
      emailVerified: data['emailVerified'] ?? false,
      preferences: data['preferences'] as Map<String, dynamic>?,
      safetyStats: data['safetyStats'] as Map<String, dynamic>?,
      emergencyContacts: emergencyContacts,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  // Factory constructor to create UserData from Firebase Auth User
  factory UserData.fromUser(User user) {
    return UserData(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? '',
      phoneNumber: user.phoneNumber ?? '',
      photoURL: user.photoURL ?? '',
      emailVerified: user.emailVerified,
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'photoURL': photoURL,
      'address': address,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'emailVerified': emailVerified,
      'preferences': preferences,
      'safetyStats': safetyStats,
      'emergencyContacts': emergencyContacts,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Create a copy with new field values
  UserData copyWith({
    String? displayName,
    String? phoneNumber,
    String? photoURL,
    String? address,
    String? emergencyContactName,
    String? emergencyContactPhone,
    bool? emailVerified,
    Map<String, dynamic>? preferences,
    Map<String, dynamic>? safetyStats,
    List<Map<String, dynamic>>? emergencyContacts,
  }) {
    return UserData(
      uid: this.uid,
      email: this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoURL: photoURL ?? this.photoURL,
      address: address ?? this.address,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone:
          emergencyContactPhone ?? this.emergencyContactPhone,
      emailVerified: emailVerified ?? this.emailVerified,
      preferences: preferences ?? this.preferences,
      safetyStats: safetyStats ?? this.safetyStats,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      createdAt: this.createdAt,
      updatedAt: this.updatedAt,
    );
  }
}
