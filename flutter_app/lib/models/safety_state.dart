import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/emergency_contact.dart';

/// Represents the state of the safety system
class SafetyState {
  final bool isSafetyModeActive;
  final Position? currentLocation;
  final bool isLocationTracking;
  final bool isEmergencyActive;
  final DateTime? lastEmergencyTime;
  final List<EmergencyContact> emergencyContacts;
  final bool isLoading;
  final String? error;

  const SafetyState({
    this.isSafetyModeActive = false,
    this.currentLocation,
    this.isLocationTracking = false,
    this.isEmergencyActive = false,
    this.lastEmergencyTime,
    this.emergencyContacts = const [],
    this.isLoading = false,
    this.error,
  });

  SafetyState copyWith({
    bool? isSafetyModeActive,
    Position? currentLocation,
    bool? isLocationTracking,
    bool? isEmergencyActive,
    DateTime? lastEmergencyTime,
    List<EmergencyContact>? emergencyContacts,
    bool? isLoading,
    String? error,
  }) {
    return SafetyState(
      isSafetyModeActive: isSafetyModeActive ?? this.isSafetyModeActive,
      currentLocation: currentLocation ?? this.currentLocation,
      isLocationTracking: isLocationTracking ?? this.isLocationTracking,
      isEmergencyActive: isEmergencyActive ?? this.isEmergencyActive,
      lastEmergencyTime: lastEmergencyTime ?? this.lastEmergencyTime,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  String get safetyStatus {
    if (isEmergencyActive) return 'Emergency Active';
    if (isSafetyModeActive) return 'Protected';
    return 'Inactive';
  }
}
