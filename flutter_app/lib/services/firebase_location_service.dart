import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Service for managing location updates in Firebase Realtime Database
class FirebaseLocationService {
  static final FirebaseLocationService _instance =
      FirebaseLocationService._internal();

  factory FirebaseLocationService() => _instance;

  FirebaseLocationService._internal() {
    _database = FirebaseDatabase.instance;
    _auth = FirebaseAuth.instance;
  }

  late FirebaseDatabase _database;
  late FirebaseAuth _auth;
  StreamSubscription<Position>? _positionStreamSubscription;
  DatabaseReference? _userPresenceRef;

  /// Get the database reference for the current user's location
  DatabaseReference? _getUserLocationRef() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('Firebase Location Service: No authenticated user');
      return null;
    }

    // Reference to user's location data
    return _database.ref('user_locations/${user.uid}');
  }

  /// Start tracking and storing location updates in Firebase
  Future<bool> startLocationTracking() async {
    try {
      final locationRef = _getUserLocationRef();
      if (locationRef == null) {
        return false;
      }

      // Make sure we have the necessary permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied');
        return false;
      }

      // First, set up online presence monitoring
      await setupOnlinePresence();

      // Store initial position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      await _updateFirebaseLocation(position);

      // Set up the stream for continuous updates
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen(_updateFirebaseLocation);

      return true;
    } catch (e) {
      debugPrint('Error starting Firebase location tracking: $e');
      return false;
    }
  }

  /// Update location data in Firebase
  Future<void> _updateFirebaseLocation(Position position) async {
    try {
      final locationRef = _getUserLocationRef();
      if (locationRef == null) {
        return;
      }

      // Get a clean timestamp string for display
      final now = DateTime.now();
      final timeString =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      final dateString =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'heading': position.heading,
        'speed': position.speed,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'timestamp': ServerValue.timestamp, // Firebase server timestamp
        'lastUpdated': '$dateString $timeString', // Human-readable timestamp
        'online': true, // Set the online flag
      };

      await locationRef.update(locationData);
    } catch (e) {
      debugPrint('Error updating Firebase location: $e');
    }
  }

  /// Update location data with a specific LatLng
  Future<void> updateLocationManually(LatLng latLng) async {
    try {
      final locationRef = _getUserLocationRef();
      if (locationRef == null) {
        return;
      }

      // Get a clean timestamp string for display
      final now = DateTime.now();
      final timeString =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      final dateString =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final locationData = {
        'latitude': latLng.latitude,
        'longitude': latLng.longitude,
        'timestamp': ServerValue.timestamp,
        'lastUpdated': '$dateString $timeString',
        'manualUpdate': true,
        'online': true, // Set the online flag
      };

      await locationRef.update(locationData);
    } catch (e) {
      debugPrint('Error manually updating Firebase location: $e');
    }
  }

  /// Stop tracking location updates
  Future<void> stopLocationTracking() async {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    // Set the user as offline
    await setUserOffline();

    debugPrint('Firebase location tracking stopped');
  }

  /// Get the current user's real-time location stream
  Stream<Map<String, dynamic>>? getUserLocationStream() {
    final locationRef = _getUserLocationRef();
    if (locationRef == null) {
      return null;
    }

    return locationRef.onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) {
        return {};
      }

      // Convert to the expected format
      return Map<String, dynamic>.from(data);
    });
  }

  /// Get a stream of all users' locations (for admin or group features)
  Stream<Map<String, Map<String, dynamic>>> getAllUsersLocationsStream() {
    final allLocationsRef = _database.ref('user_locations');

    return allLocationsRef.onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) {
        return {};
      }

      // Convert nested maps
      final result = <String, Map<String, dynamic>>{};
      data.forEach((key, value) {
        if (value is Map) {
          result[key.toString()] = Map<String, dynamic>.from(value);
        }
      });

      return result;
    });
  }

  /// Set up the user's online status management
  Future<void> setupOnlinePresence() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('Cannot set up online presence: No authenticated user');
      return;
    }

    try {
      _userPresenceRef = _database.ref('user_locations/${user.uid}/online');

      // Set up connection monitoring
      final connectedRef = _database.ref('.info/connected');
      connectedRef.onValue.listen((event) {
        final connected = event.snapshot.value as bool? ?? false;
        if (connected) {
          debugPrint('Firebase connection established, setting online status');
          _setUserOnline();
        } else {
          debugPrint('Firebase connection lost');
        }
      });
    } catch (e) {
      debugPrint('Error setting up online presence: $e');
    }
  }

  /// Mark the user as online
  Future<void> _setUserOnline() async {
    if (_userPresenceRef == null) {
      return;
    }

    try {
      // Set the online flag in the database
      await _userPresenceRef!.set(true);

      // Set up an onDisconnect event that will set online to false when the connection is lost
      await _userPresenceRef!.onDisconnect().set(false);

      debugPrint('User marked as online');
    } catch (e) {
      debugPrint('Error setting online status: $e');
    }
  }

  /// Mark the user as offline
  Future<void> setUserOffline() async {
    if (_userPresenceRef == null) {
      return;
    }

    try {
      // Cancel the onDisconnect operation
      await _userPresenceRef!.onDisconnect().cancel();

      // Set the online flag to false
      await _userPresenceRef!.set(false);

      debugPrint('User marked as offline');
    } catch (e) {
      debugPrint('Error setting offline status: $e');
    }
  }

  /// Get the online status of a specific user
  Stream<bool>? getUserOnlineStatus(String userId) {
    if (userId.isEmpty) {
      return null;
    }

    final userStatusRef = _database.ref('user_locations/$userId/online');
    return userStatusRef.onValue.map((event) {
      return event.snapshot.value as bool? ?? false;
    });
  }

  /// Get the online status of the current user
  Stream<bool>? getCurrentUserOnlineStatus() {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }

    return getUserOnlineStatus(user.uid);
  }
}
