import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_contact.dart';
import '../models/safety_state.dart';
import '../services/user_data_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing emergency contacts
class ContactService {
  final UserDataService _userDataService = UserDataService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user id
  String? get currentUserId => _auth.currentUser?.uid;

  /// Add a new emergency contact
  SafetyState addEmergencyContact(
    SafetyState currentState,
    EmergencyContact contact,
  ) {
    final updatedContacts = [...currentState.emergencyContacts, contact];
    final newState = currentState.copyWith(emergencyContacts: updatedContacts);
    _saveEmergencyContacts(newState.emergencyContacts);

    // Also save to Firestore if user is logged in
    _syncContactsWithFirestore(updatedContacts);

    return newState;
  }

  /// Remove an emergency contact
  SafetyState removeEmergencyContact(
    SafetyState currentState,
    String contactId,
  ) {
    final updatedContacts =
        currentState.emergencyContacts.where((c) => c.id != contactId).toList();
    final newState = currentState.copyWith(emergencyContacts: updatedContacts);
    _saveEmergencyContacts(newState.emergencyContacts);

    // Also remove from Firestore if user is logged in
    _syncContactsWithFirestore(updatedContacts);

    return newState;
  }

  /// Update an existing emergency contact
  SafetyState updateEmergencyContact(
    SafetyState currentState,
    EmergencyContact updatedContact,
  ) {
    final updatedContacts =
        currentState.emergencyContacts.map((contact) {
          return contact.id == updatedContact.id ? updatedContact : contact;
        }).toList();
    final newState = currentState.copyWith(emergencyContacts: updatedContacts);
    _saveEmergencyContacts(newState.emergencyContacts);

    // Also update in Firestore if user is logged in
    _syncContactsWithFirestore(updatedContacts);

    return newState;
  }

  /// Sync emergency contacts with Firestore
  Future<void> _syncContactsWithFirestore(
    List<EmergencyContact> contacts,
  ) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      // Convert contacts to Maps for Firestore
      final contactMaps = contacts.map((contact) => contact.toJson()).toList();

      // Save to Firestore
      await _userDataService.saveEmergencyContacts(uid, contactMaps);
      debugPrint('✅ Emergency contacts synced with Firestore');
    } catch (e) {
      debugPrint('❌ Error syncing emergency contacts with Firestore: $e');
    }
  }

  /// Load emergency contacts from Firestore if available, otherwise from local storage
  Future<SafetyState> loadEmergencyContacts(SafetyState currentState) async {
    final uid = currentUserId;

    if (uid != null) {
      try {
        // Try loading from Firestore first
        final contactMaps = await _userDataService.getEmergencyContacts(uid);
        if (contactMaps.isNotEmpty) {
          final contacts =
              contactMaps
                  .map(
                    (map) => EmergencyContact.fromJson(
                      Map<String, dynamic>.from(map),
                    ),
                  )
                  .toList();

          // Also save to local storage as backup
          await _saveEmergencyContacts(contacts);

          debugPrint(
            '✅ Loaded ${contacts.length} emergency contacts from Firestore',
          );
          return currentState.copyWith(emergencyContacts: contacts);
        }
      } catch (e) {
        debugPrint('❌ Error loading contacts from Firestore: $e');
        // Fall back to local storage if Firestore fails
      }
    }

    // If Firestore loading failed or user not logged in, try loading from local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactsJson = prefs.getStringList('emergency_contacts') ?? [];

      final contacts =
          contactsJson.map((jsonStr) {
            final json = jsonDecode(jsonStr) as Map<String, dynamic>;
            return EmergencyContact.fromJson(json);
          }).toList();

      // If we have contacts locally but not in Firestore, sync them up
      if (contacts.isNotEmpty && uid != null) {
        _syncContactsWithFirestore(contacts);
      }

      return currentState.copyWith(emergencyContacts: contacts);
    } catch (e) {
      debugPrint('❌ Error loading emergency contacts from local storage: $e');
      return currentState;
    }
  }

  /// Save emergency contacts to SharedPreferences
  Future<void> _saveEmergencyContacts(List<EmergencyContact> contacts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactsJson =
          contacts.map((contact) => jsonEncode(contact.toJson())).toList();

      await prefs.setStringList('emergency_contacts', contactsJson);
    } catch (e) {
      debugPrint('Error saving emergency contacts: $e');
    }
  }

  /// Add default contacts for demo purposes
  SafetyState addDefaultContacts(SafetyState currentState) {
    // Only add defaults if no contacts exist
    if (currentState.emergencyContacts.isNotEmpty) {
      return currentState;
    }

    final defaultContacts = [
      EmergencyContact(
        id: 'default_1',
        name: 'Mom',
        phone: '+1 234 567 8900',
        relationship: 'Family',
        isActive: true,
        priority: 1,
      ),
      EmergencyContact(
        id: 'default_2',
        name: 'Dad',
        phone: '+1 234 567 8901',
        relationship: 'Family',
        isActive: true,
        priority: 2,
      ),
      EmergencyContact(
        id: 'default_3',
        name: 'Best Friend Sarah',
        phone: '+1 234 567 8902',
        relationship: 'Friend',
        isActive: false,
        priority: 3,
      ),
    ];

    final newState = currentState.copyWith(emergencyContacts: defaultContacts);
    _saveEmergencyContacts(defaultContacts);
    return newState;
  }

  /// Validates if a phone number has a basic valid format
  bool isValidPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters for validation
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Check if it has at least 7 digits and at most 15 digits (international standard)
    if (digitsOnly.length < 7 || digitsOnly.length > 15) {
      return false;
    }

    // Check if the original contains valid phone characters
    final validChars = RegExp(r'^[\d\s\+\(\)\-\.]+$');
    return validChars.hasMatch(phoneNumber);
  }
}
