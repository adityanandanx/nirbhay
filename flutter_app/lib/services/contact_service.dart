import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_contact.dart';
import '../models/safety_state.dart';

/// Service for managing emergency contacts
class ContactService {
  /// Add a new emergency contact
  SafetyState addEmergencyContact(
    SafetyState currentState,
    EmergencyContact contact,
  ) {
    final updatedContacts = [...currentState.emergencyContacts, contact];
    final newState = currentState.copyWith(emergencyContacts: updatedContacts);
    _saveEmergencyContacts(newState.emergencyContacts);
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
    return newState;
  }

  /// Load emergency contacts from SharedPreferences
  Future<SafetyState> loadEmergencyContacts(SafetyState currentState) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactsJson = prefs.getStringList('emergency_contacts') ?? [];

      final contacts =
          contactsJson.map((jsonStr) {
            final json = jsonDecode(jsonStr) as Map<String, dynamic>;
            return EmergencyContact.fromJson(json);
          }).toList();

      return currentState.copyWith(emergencyContacts: contacts);
    } catch (e) {
      debugPrint('Error loading emergency contacts: $e');
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
