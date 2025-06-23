import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/emergency_contact.dart';
import '../models/safety_state.dart';
import '../services/contact_service.dart';
import '../services/emergency_service.dart';
import '../services/location_service.dart';
import 'ble_provider.dart';
import 'settings_provider.dart';

/// Safety Provider
/// This is the main provider for the safety features of the app
/// It orchestrates all the safety-related services
class SafetyStateNotifier extends StateNotifier<SafetyState> {
  SafetyStateNotifier(this._bleStateNotifier, this._settingsNotifier)
    : super(const SafetyState()) {
    _init();
  }

  final BLEStateNotifier _bleStateNotifier;
  final SettingsStateNotifier _settingsNotifier;

  // Services
  late final ContactService _contactService;
  late final LocationService _locationService;
  late final EmergencyService _emergencyService;

  StreamSubscription<BLEState>? _bleStateSubscription;

  void _init() async {
    // Initialize services
    _contactService = ContactService();
    _locationService = LocationService();
    _emergencyService = EmergencyService(_settingsNotifier.state);

    // Set up location update callback
    _locationService.setPositionUpdateCallback(_handlePositionUpdate);

    // Load emergency contacts from persistent storage
    state = await _contactService.loadEmergencyContacts(state);

    // Add default contacts if none exist (for demo purposes)
    if (state.emergencyContacts.isEmpty) {
      state = _contactService.addDefaultContacts(state);
    }

    // Check SMS permissions on initialization
    state = await _emergencyService.checkSmsPermissions(state);

    // Listen to BLE state changes for sensor data and connection status
    _bleStateSubscription = _bleStateNotifier.stream.listen((bleState) {
      // If safety mode is active but device disconnected, show warning but keep safety mode active
      if (state.isSafetyModeActive && !bleState.isConnected) {
        state = state.copyWith(
          error:
              'Warning: Wearable device disconnected. Safety mode continues with phone-only features.',
        );
      }

      // Check sensor data for automatic threat detection (only if device is connected)
      if (bleState.sensorData != null &&
          state.isSafetyModeActive &&
          bleState.isConnected) {
        _checkForThreat(bleState.sensorData!);
      }
    });
  }

  void _handlePositionUpdate(Position position) {
    // Update state with new position
    state = state.copyWith(currentLocation: position);
  }

  // Helper method to check if safety mode can be activated
  bool get canActivateSafetyMode {
    return true; // Safety mode can always be activated
  }

  Future<void> toggleSafetyMode() async {
    final newState = !state.isSafetyModeActive;
    state = state.copyWith(isSafetyModeActive: newState, isLoading: true);

    try {
      // Try to notify connected BLE device if available
      if (_bleStateNotifier.mounted && _bleStateNotifier.state.isConnected) {
        try {
          await _bleStateNotifier.setSafetyMode(newState);
        } catch (e) {
          // BLE notification failed, but continue with safety mode activation
          debugPrint('BLE safety mode notification failed: $e');
        }
      }

      // Start/stop location tracking based on safety mode
      if (newState) {
        state = await _locationService.startLocationTracking(state);
      } else {
        state = _locationService.stopLocationTracking(state);
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isSafetyModeActive: !newState, // Revert on error
        isLoading: false,
        error: 'Failed to toggle safety mode: ${e.toString()}',
      );
    }
  }

  Future<void> triggerEmergencyAlert() async {
    try {
      // Get current location for emergency if not already tracking
      Position? currentLocation;
      if (state.currentLocation == null) {
        currentLocation = await _locationService.getCurrentLocation();
      }

      // Trigger emergency through the service
      state = await _emergencyService.triggerEmergencyAlert(
        state,
        currentLocation,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to send emergency alert: ${e.toString()}',
      );
    }
  }

  Future<void> _checkForThreat(Map<String, dynamic> sensorData) async {
    try {
      // Use emergency service to detect potential threats
      final updatedState = await _emergencyService.detectPotentialThreat(
        state,
        sensorData,
      );

      // Update state if there's a detected threat
      if (updatedState.error != null &&
          updatedState.error!.contains('Potential threat detected')) {
        state = updatedState;

        // Start countdown before triggering emergency alert
        await _startEmergencyCountdown();
      }
    } catch (e) {
      debugPrint('Error detecting threat: $e');
    }
  }

  Future<void> cancelEmergencyAlert() async {
    try {
      state = await _emergencyService.cancelEmergencyAlert(state);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to cancel emergency alert: ${e.toString()}',
      );
    }
  }

  void addEmergencyContact(EmergencyContact contact) {
    state = _contactService.addEmergencyContact(state, contact);
  }

  void removeEmergencyContact(String contactId) {
    state = _contactService.removeEmergencyContact(state, contactId);
  }

  void updateEmergencyContact(EmergencyContact updatedContact) {
    state = _contactService.updateEmergencyContact(state, updatedContact);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Request SMS permissions manually (can be called from UI)
  Future<bool> requestSmsPermissions() async {
    try {
      bool permissionsGranted = await _emergencyService.requestSmsPermissions();

      if (permissionsGranted) {
        // Clear any permission-related errors
        if (state.error != null && state.error!.contains('SMS permissions')) {
          state = state.copyWith(error: null);
        }
      } else {
        state = state.copyWith(
          error: 'SMS permissions denied. Emergency SMS alerts will not work.',
        );
      }

      return permissionsGranted;
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to request SMS permissions: ${e.toString()}',
      );
      return false;
    }
  }

  /// Check if SMS permissions are currently granted
  Future<bool> get hasSmsPermissions async {
    return await _emergencyService.hasSmsPermissions();
  }

  /// Send a test SMS to verify functionality
  Future<bool> sendTestSms(String phoneNumber) async {
    try {
      await _emergencyService.sendTestSms(phoneNumber);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to send test SMS: ${e.toString()}');
      return false;
    }
  }

  @override
  void dispose() {
    _bleStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startEmergencyCountdown() async {
    final settings = _settingsNotifier.state;

    // TODO: Implement actual countdown with user interaction
    // This would show a countdown dialog/screen where user can cancel
    await Future.delayed(Duration(seconds: settings.sosCountdownTime));

    // If not cancelled by user, trigger emergency alert
    if (state.error != null &&
        state.error!.contains('Potential threat detected')) {
      await triggerEmergencyAlert();
    }
  }
}
