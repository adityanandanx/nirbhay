import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/firebase_location_service.dart';

// Provider for the Firebase Location Service
final firebaseLocationServiceProvider = Provider<FirebaseLocationService>((
  ref,
) {
  return FirebaseLocationService();
});

// State class for location tracking
class LocationTrackingState {
  final bool isTracking;
  final bool isLoading;
  final String? error;
  final LatLng? currentLocation;
  final Position? rawPosition;
  final bool isSharingLocation;

  LocationTrackingState({
    this.isTracking = false,
    this.isLoading = false,
    this.error,
    this.currentLocation,
    this.rawPosition,
    this.isSharingLocation = false,
  });

  LocationTrackingState copyWith({
    bool? isTracking,
    bool? isLoading,
    String? error,
    LatLng? currentLocation,
    Position? rawPosition,
    bool? isSharingLocation,
  }) {
    return LocationTrackingState(
      isTracking: isTracking ?? this.isTracking,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentLocation: currentLocation ?? this.currentLocation,
      rawPosition: rawPosition ?? this.rawPosition,
      isSharingLocation: isSharingLocation ?? this.isSharingLocation,
    );
  }
}

// State notifier for location tracking
class LocationTrackingNotifier extends StateNotifier<LocationTrackingState> {
  final FirebaseLocationService _locationService;

  LocationTrackingNotifier(this._locationService)
    : super(LocationTrackingState());

  // Start location tracking and Firebase updates
  Future<void> startLocationTracking() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final success = await _locationService.startLocationTracking();
      if (success) {
        state = state.copyWith(
          isTracking: true,
          isLoading: false,
          isSharingLocation: true,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to start location tracking',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Error: ${e.toString()}');
    }
  }

  // Stop location tracking
  Future<void> stopLocationTracking() async {
    await _locationService.stopLocationTracking();
    state = state.copyWith(isTracking: false, isSharingLocation: false);
  }

  // Toggle location sharing
  Future<void> toggleLocationSharing() async {
    if (state.isSharingLocation) {
      await stopLocationTracking();
    } else {
      await startLocationTracking();
    }
  }

  // Update current location manually
  Future<void> updateLocation(LatLng location) async {
    state = state.copyWith(currentLocation: location);

    if (state.isSharingLocation) {
      await _locationService.updateLocationManually(location);
    }
  }

  // Update location from a Position object
  void updateLocationFromPosition(Position position) {
    final latLng = LatLng(position.latitude, position.longitude);
    state = state.copyWith(currentLocation: latLng, rawPosition: position);
  }
}

// Provider for location tracking state
final locationTrackingProvider =
    StateNotifierProvider<LocationTrackingNotifier, LocationTrackingState>((
      ref,
    ) {
      final locationService = ref.watch(firebaseLocationServiceProvider);
      return LocationTrackingNotifier(locationService);
    });
