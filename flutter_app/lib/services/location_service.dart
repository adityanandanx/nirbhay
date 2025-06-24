import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/safety_state.dart';

/// Service for managing location tracking and permissions
class LocationService {
  /// Check permissions and start location tracking
  Future<SafetyState> startLocationTracking(SafetyState currentState) async {
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

      // Start listening to location updates
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen((Position position) {
        // This will be handled by the provider to update state
        _onPositionUpdate?.call(position);
      });

      return currentState.copyWith(
        currentLocation: position,
        isLocationTracking: true,
      );
    } catch (e) {
      debugPrint('Location error: $e');
      return currentState.copyWith(
        error: 'Failed to start location tracking: ${e.toString()}',
      );
    }
  }

  /// Stop location tracking
  SafetyState stopLocationTracking(SafetyState currentState) {
    return currentState.copyWith(
      isLocationTracking: false,
      currentLocation: null,
    );
  }

  /// Get current location immediately
  Future<Position?> getCurrentLocation() async {
    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get current location
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return null;
    }
  }

  /// Callback for position updates
  void Function(Position position)? _onPositionUpdate;

  /// Set callback for position updates
  void setPositionUpdateCallback(void Function(Position position) callback) {
    _onPositionUpdate = callback;
  }
}
