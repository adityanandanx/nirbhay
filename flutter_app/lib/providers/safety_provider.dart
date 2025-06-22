import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'ble_provider.dart';

// Safety State Model
class SafetyState {
  final bool isSafetyModeActive;
  final Position? currentLocation;
  final bool isLocationTracking;
  final bool isEmergencyActive;
  final DateTime? lastEmergencyTime;
  final List<String> emergencyContacts;
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
    List<String>? emergencyContacts,
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

// Safety State Notifier
class SafetyStateNotifier extends StateNotifier<SafetyState> {
  SafetyStateNotifier(this._bleStateNotifier) : super(const SafetyState());

  final BLEStateNotifier _bleStateNotifier;

  Future<void> toggleSafetyMode() async {
    final newState = !state.isSafetyModeActive;
    state = state.copyWith(isSafetyModeActive: newState, isLoading: true);

    try {
      // Notify connected BLE device
      await _bleStateNotifier.setSafetyMode(newState);

      // Start/stop location tracking based on safety mode
      if (newState) {
        await _startLocationTracking();
      } else {
        await _stopLocationTracking();
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

  Future<void> _startLocationTracking() async {
    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Get current location
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      );

      state = state.copyWith(
        currentLocation: position,
        isLocationTracking: true,
      );

      // Start listening to location updates
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen((Position position) {
        state = state.copyWith(currentLocation: position);
      });
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to start location tracking: ${e.toString()}',
      );
    }
  }

  Future<void> _stopLocationTracking() async {
    state = state.copyWith(isLocationTracking: false, currentLocation: null);
  }

  Future<void> triggerEmergencyAlert() async {
    state = state.copyWith(
      isEmergencyActive: true,
      lastEmergencyTime: DateTime.now(),
      isLoading: true,
    );

    try {
      // Send emergency alert to BLE device
      await _bleStateNotifier.sendEmergencyAlert();

      // Get current location for emergency
      if (state.currentLocation == null) {
        final position = await Geolocator.getCurrentPosition();
        state = state.copyWith(currentLocation: position);
      }

      // TODO: Send emergency notifications to contacts
      await _sendEmergencyNotifications();

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to send emergency alert: ${e.toString()}',
      );
    }
  }

  Future<void> _sendEmergencyNotifications() async {
    // TODO: Implement emergency notification logic
    // This would include:
    // - Sending SMS to emergency contacts
    // - Calling emergency services if configured
    // - Sending push notifications
    // - Logging the emergency event
  }

  Future<void> cancelEmergencyAlert() async {
    state = state.copyWith(isEmergencyActive: false, isLoading: true);

    try {
      // TODO: Cancel emergency notifications
      // - Cancel any pending emergency calls
      // - Notify contacts that emergency is cancelled

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to cancel emergency alert: ${e.toString()}',
      );
    }
  }

  void addEmergencyContact(String contact) {
    final updatedContacts = [...state.emergencyContacts, contact];
    state = state.copyWith(emergencyContacts: updatedContacts);
  }

  void removeEmergencyContact(String contact) {
    final updatedContacts =
        state.emergencyContacts.where((c) => c != contact).toList();
    state = state.copyWith(emergencyContacts: updatedContacts);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}
