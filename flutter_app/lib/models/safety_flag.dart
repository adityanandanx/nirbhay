import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';

class SafetyFlag {
  final String id;
  final LatLng location;
  final String createdBy;
  final DateTime createdAt;
  final String? description;
  static const double radius = 100.0; // Radius in meters

  SafetyFlag({
    required this.id,
    required this.location,
    required this.createdBy,
    required this.createdAt,
    this.description,
  });

  // Calculate opacity based on time remaining
  double getOpacity() {
    final now = DateTime.now();
    final timeDiff = now.difference(createdAt);
    final lifetime = const Duration(hours: 24);

    if (timeDiff >= lifetime) return 0.0;
    return 1.0 - (timeDiff.inMinutes / lifetime.inMinutes);
  }

  // Check if the flag is still valid
  bool isValid() {
    final now = DateTime.now();
    return now.difference(createdAt) < const Duration(hours: 24);
  }

  // Convert to JSON for Firebase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'description': description,
    };
  }

  // Create from JSON from Firebase
  factory SafetyFlag.fromJson(Map<String, dynamic> json) {
    return SafetyFlag(
      id: json['id'] as String,
      location: LatLng(json['latitude'] as double, json['longitude'] as double),
      createdBy: json['createdBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      description: json['description'] as String?,
    );
  }

  Circle getCircle() {
    return Circle(
      circleId: CircleId('circle_$id'),
      center: location,
      radius: radius, // 100 meters radius
      fillColor: Colors.red.withOpacity(getOpacity() * 0.2),
      strokeColor: Colors.red.withOpacity(getOpacity()),
      strokeWidth: 2,
    );
  }
}
