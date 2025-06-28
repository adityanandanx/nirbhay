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
  final bool isVoiceDetectionActive;
  final bool isEmergencyCountdownActive;
  final DateTime? emergencyCountdownStartTime;
  final (String, double)? detectedSound; // Tuple of (sound label, confidence)

  const SafetyState({
    this.isSafetyModeActive = false,
    this.currentLocation,
    this.isLocationTracking = false,
    this.isEmergencyActive = false,
    this.lastEmergencyTime,
    this.emergencyContacts = const [],
    this.isLoading = false,
    this.error,
    this.isVoiceDetectionActive = false,
    this.isEmergencyCountdownActive = false,
    this.emergencyCountdownStartTime,
    this.detectedSound,
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
    bool? isVoiceDetectionActive,
    bool? isEmergencyCountdownActive,
    DateTime? emergencyCountdownStartTime,
    (String, double)? detectedSound,
  }) {
    return SafetyState(
      isSafetyModeActive: isSafetyModeActive ?? this.isSafetyModeActive,
      currentLocation: currentLocation ?? this.currentLocation,
      isLocationTracking: isLocationTracking ?? this.isLocationTracking,
      isEmergencyActive: isEmergencyActive ?? this.isEmergencyActive,
      lastEmergencyTime: lastEmergencyTime ?? this.lastEmergencyTime,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      isLoading: isLoading ?? this.isLoading,
      error: error,  // Intentionally not using ?? to allow setting to null
      isVoiceDetectionActive: isVoiceDetectionActive ?? this.isVoiceDetectionActive,
      isEmergencyCountdownActive: isEmergencyCountdownActive ?? this.isEmergencyCountdownActive,
      emergencyCountdownStartTime: emergencyCountdownStartTime ?? this.emergencyCountdownStartTime,
      detectedSound: detectedSound,  // Intentionally not using ?? to allow setting to null
    );
  }

  String get safetyStatus {
    if (isEmergencyActive) return 'Emergency Active';
    if (isSafetyModeActive) return 'Protected';
    return 'Inactive';
  }
}
