import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/app_providers.dart';
import '../providers/safety_flags_provider.dart';
import '../models/safety_flag.dart';

// This is an extended version of LocationMapSection for a full screen map view
class FullscreenMapView extends ConsumerStatefulWidget {
  const FullscreenMapView({super.key});

  @override
  ConsumerState<FullscreenMapView> createState() => _FullscreenMapViewState();
}

class _FullscreenMapViewState extends ConsumerState<FullscreenMapView> {
  final Completer<GoogleMapController> _controller = Completer();
  LatLng? _currentPosition;
  bool _isLoading = true;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<Map<String, Map<String, dynamic>>>?
  _usersLocationSubscription;
  String? _currentUserId;

  // We'll use default markers with different hues instead of custom markers

  // Filter settings for user markers
  bool _showOfflineUsers = true;
  bool _autoFollowCurrentUser = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();

    // Start the real-time location updates after a short delay to allow UI to build
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        final locationTracker = ref.read(locationTrackingProvider.notifier);
        locationTracker.startLocationTracking();

        // Set up position stream for live updates on the map
        _positionStreamSubscription = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 1, // Update every 10 meters
          ),
        ).listen(_handlePositionUpdate);
      }
    });

    // Subscribe to other users' locations
    _subscribeToUsersLocations();
  }

  @override
  void dispose() {
    // Clean up the position stream when the widget is disposed
    _positionStreamSubscription?.cancel();
    _usersLocationSubscription?.cancel();
    super.dispose();
  }

  void _handlePositionUpdate(Position position) {
    if (mounted) {
      final latLng = LatLng(position.latitude, position.longitude);

      // Update the location tracking provider
      ref
          .read(locationTrackingProvider.notifier)
          .updateLocationFromPosition(position);

      setState(() {
        _currentPosition = latLng;

        // Don't replace all markers, just update current user
        // We'll let the _updateUserMarkers method handle the markers
      });

      // Animate the camera to follow the user's location
      // _animateToCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (mounted) {
        final latLng = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentPosition = latLng;
          _isLoading = false;
          // Don't update markers here - let _updateUserMarkers handle it
        });

        _animateToCurrentLocation();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _animateToCurrentLocation() async {
    if (_currentPosition != null && _controller.isCompleted) {
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentPosition!, zoom: 15),
        ),
      );
    }
  }

  // Listen to all users' locations and update markers
  void _subscribeToUsersLocations() {
    // Get the current user ID from Firebase auth
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;

    // Subscribe to all user locations
    final locationService = ref.read(firebaseLocationServiceProvider);
    _usersLocationSubscription = locationService
        .getAllUsersLocationsStream()
        .listen(_updateUserMarkers);
  }

  // Update map markers based on users' locations
  void _updateUserMarkers(Map<String, Map<String, dynamic>> usersData) {
    if (!mounted) return;

    // Create a new set of markers
    final updatedMarkers = <Marker>{};

    // Process each user's data
    usersData.forEach((userId, userData) {
      // Skip if missing essential data
      if (!userData.containsKey('latitude') ||
          !userData.containsKey('longitude')) {
        return;
      }

      // Extract location data
      final latitude = userData['latitude'] as double;
      final longitude = userData['longitude'] as double;
      final location = LatLng(latitude, longitude);
      final bool isOnline = userData['online'] as bool? ?? false;
      final bool isCurrentUser = userId == _currentUserId;

      // Skip offline users if filtered out
      if (!isCurrentUser && !isOnline && !_showOfflineUsers) {
        return;
      }

      // Get marker hue based on user status
      final double markerHue =
          isCurrentUser
              ? BitmapDescriptor
                  .hueAzure // Blue for current user
              : isOnline
              ? BitmapDescriptor
                  .hueGreen // Green for online users
              : BitmapDescriptor.hueViolet; // Violet for offline users

      // Create user name or truncated ID for display
      final String userName =
          userData['userName'] as String? ??
          'User ${userId.substring(0, min(userId.length, 6))}';

      // Generate user status text
      final String statusText =
          isOnline
              ? 'Online now'
              : 'Last seen: ${userData['lastUpdated'] ?? 'Unknown'}';

      // Create the marker using only built-in Google Maps markers
      final marker = Marker(
        markerId: MarkerId(userId),
        position: location,
        icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
        infoWindow: InfoWindow(
          title: isCurrentUser ? 'You' : userName,
          snippet: statusText,
        ),
        // Current user on top, then online users, then offline
        zIndex: isCurrentUser ? 2 : (isOnline ? 1 : 0),
      );

      // Add to the updated marker set
      updatedMarkers.add(marker);
    });

    // Update the state with the new markers
    setState(() {
      _markers = updatedMarkers;
    });
  }

  // Update map markers and circles to include both user locations and safety flags
  void _updateMapMarkers() {
    final Set<Marker> updatedMarkers = {}..addAll(_markers);
    final Set<Circle> updatedCircles = {};

    // Add safety flags from the provider
    final safetyFlags = ref.read(safetyFlagsProvider);
    safetyFlags.whenData((flags) {
      for (final flag in flags) {
        if (flag.isValid()) {
          final opacity = flag.getOpacity();
          updatedMarkers.add(
            Marker(
              markerId: MarkerId('flag_${flag.id}'),
              position: flag.location,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
              alpha: opacity,
              infoWindow: InfoWindow(
                title: 'Unsafe Area',
                snippet:
                    flag.description ??
                    'Reported ${_getTimeAgo(flag.createdAt)}',
              ),
              onTap: () => _showFlagDetails(flag),
            ),
          );
          // Add circle for each flag
          updatedCircles.add(flag.getCircle());
        }
      }
    });

    if (mounted) {
      setState(() {
        _markers = updatedMarkers;
        _circles = updatedCircles;
      });
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _showFlagDetails(SafetyFlag flag) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Unsafe Area Report',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (flag.description != null) ...[
                  Text(
                    'Description:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(flag.description!),
                  const SizedBox(height: 12),
                ],
                Text(
                  'Reported: ${_getTimeAgo(flag.createdAt)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'This flag will automatically expire in ${_getRemainingTime(flag.createdAt)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
    );
  }

  String _getRemainingTime(DateTime createdAt) {
    final expiryTime = createdAt.add(Duration(hours: 24));
    final remaining = expiryTime.difference(DateTime.now());

    if (remaining.inHours > 1) {
      return '${remaining.inHours} hours';
    } else {
      return '${remaining.inMinutes} minutes';
    }
  }

  // Add floating action button to report current location
  Widget _buildReportButton() {
    return Positioned(
      left: 16,
      bottom: 16, // Position above other controls
      child: FloatingActionButton(
        heroTag: 'reportLocation',
        backgroundColor: Colors.red,
        onPressed: _showAddFlagDialog,
        child: Icon(Icons.warning_amber_rounded, color: Colors.white),
      ),
    );
  }

  void _showAddFlagDialog() {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to get your current location'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red),
                const SizedBox(width: 8),
                Text('Report Location'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'This will mark your current location as unsafe for the next 24 hours.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'A ${SafetyFlag.radius.toStringAsFixed(0)}-meter radius around this point will be marked.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'What makes this area unsafe?',
                    border: OutlineInputBorder(),
                  ),
                  textAlignVertical: TextAlignVertical.top,
                  maxLines: 5,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final userId = FirebaseAuth.instance.currentUser?.uid;
                  if (userId != null && _currentPosition != null) {
                    ref
                        .read(safetyFlagsNotifierProvider.notifier)
                        .addSafetyFlag(
                          _currentPosition!,
                          userId,
                          description:
                              descriptionController.text.isEmpty
                                  ? null
                                  : descriptionController.text,
                        );
                  }
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('Report'),
              ),
            ],
          ),
    );
  }

  // Toggle showing offline users
  void _toggleShowOfflineUsers() {
    setState(() {
      _showOfflineUsers = !_showOfflineUsers;
    });

    // Refresh markers with the latest data
    final firebaseLocationService = ref.read(firebaseLocationServiceProvider);
    firebaseLocationService.getAllUsersLocationsStream().first.then((userData) {
      if (mounted) {
        _updateUserMarkers(userData);

        // Show feedback to the user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _showOfflineUsers
                  ? 'Showing all users'
                  : 'Showing only online users',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  // Toggle auto-follow current user
  void _toggleAutoFollow() {
    setState(() {
      _autoFollowCurrentUser = !_autoFollowCurrentUser;
    });

    if (_autoFollowCurrentUser && _currentPosition != null) {
      _animateToCurrentLocation();
    }
  }

  // Function removed - we're handling navigation through other methods

  // Build map control buttons
  Widget _buildMapControls() {
    return Positioned(
      right: 16,
      bottom: 100,
      child: Column(
        children: [
          // My location button
          FloatingActionButton(
            heroTag: 'myLocation',
            mini: true,
            onPressed: () {
              _animateToCurrentLocation();
            },
            backgroundColor: Colors.white,
            child: Icon(
              Icons.my_location,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 8),

          // Auto-follow toggle
          FloatingActionButton(
            heroTag: 'autoFollow',
            mini: true,
            onPressed: _toggleAutoFollow,
            backgroundColor:
                _autoFollowCurrentUser
                    ? Theme.of(context).primaryColor
                    : Colors.white,
            child: Icon(
              Icons.navigation,
              color:
                  _autoFollowCurrentUser
                      ? Colors.white
                      : Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 8),

          // Toggle showing offline users
          FloatingActionButton(
            heroTag: 'toggleOffline',
            mini: true,
            onPressed: _toggleShowOfflineUsers,
            backgroundColor:
                _showOfflineUsers
                    ? Theme.of(context).primaryColor
                    : Colors.white,
            child: Icon(
              _showOfflineUsers ? Icons.people : Icons.person_outline,
              color:
                  _showOfflineUsers
                      ? Colors.white
                      : Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch safety flags
    final safetyFlags = ref.watch(safetyFlagsProvider);

    // Update markers when safety flags change
    safetyFlags.whenData((flags) {
      _updateMapMarkers();
    });

    return Stack(
      children: [
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _currentPosition == null
            ? _buildLocationAccessError()
            : GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: CameraPosition(
                target: _currentPosition!,
                zoom: 15,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
              markers: _markers,
              circles: _circles,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
            ),

        // Map controls overlay
        _buildMapControls(),

        // Report button
        _buildReportButton(),

        // Help tooltip
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Card(
            color: Colors.white.withOpacity(0.9),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Use the red button to mark your current location as unsafe',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationAccessError() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, color: Colors.grey[600], size: 40),
            const SizedBox(height: 16),
            Text(
              'Location access is required\nto display the map',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await _getCurrentLocation();
              },
              child: const Text('Enable Location'),
            ),
          ],
        ),
      ),
    );
  }
}
