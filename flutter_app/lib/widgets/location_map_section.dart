import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocationMapSection extends ConsumerStatefulWidget {
  const LocationMapSection({super.key});

  @override
  ConsumerState<LocationMapSection> createState() => _LocationMapSectionState();
}

class _LocationMapSectionState extends ConsumerState<LocationMapSection> {
  final Completer<GoogleMapController> _controller = Completer();
  LatLng? _currentPosition;
  bool _isLoading = true;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check and request location permissions
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

      // Get current position using the updated approach without deprecated parameter
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
          _markers = {
            Marker(
              markerId: const MarkerId('currentLocation'),
              position: latLng,
              infoWindow: const InfoWindow(title: 'Current Location'),
            ),
          };
          _isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Location',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child:
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
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
                    markers: _markers,
                    onMapCreated: (GoogleMapController controller) {
                      _controller.complete(controller);
                    },
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
