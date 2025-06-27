import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/safety_flag.dart';

class SafetyFlagService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref(
    'safety_flags',
  );
  final Duration _flagLifetime = const Duration(hours: 24);
  Timer? _cleanupTimer;

  // Start listening to safety flags and cleanup expired ones periodically
  Stream<List<SafetyFlag>> listenToSafetyFlags() {
    _startCleanupTimer();

    return _database.onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];

      final flags =
          data.entries
              .map((entry) {
                return SafetyFlag.fromJson(
                  Map<String, dynamic>.from(entry.value as Map),
                );
              })
              .where((flag) => flag.isValid())
              .toList();

      return flags;
    });
  }

  // Add a new safety flag
  Future<void> addSafetyFlag(
    LatLng location,
    String userId, {
    String? description,
  }) async {
    final flag = SafetyFlag(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      location: location,
      createdBy: userId,
      createdAt: DateTime.now(),
      description: description,
    );

    await _database.child(flag.id).set(flag.toJson());
  }

  // Remove a specific flag
  Future<void> removeSafetyFlag(String flagId) async {
    await _database.child(flagId).remove();
  }

  // Cleanup expired flags periodically
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _cleanupExpiredFlags();
    });
  }

  // Remove expired flags from the database
  Future<void> _cleanupExpiredFlags() async {
    final snapshot = await _database.get();
    final data = snapshot.value as Map<dynamic, dynamic>?;

    if (data == null) return;

    for (var entry in data.entries) {
      final flag = SafetyFlag.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
      );
      if (!flag.isValid()) {
        await _database.child(flag.id).remove();
      }
    }
  }

  // Dispose of the cleanup timer
  void dispose() {
    _cleanupTimer?.cancel();
  }
}
