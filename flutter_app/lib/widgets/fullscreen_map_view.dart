import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
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
          _markers = {
            Marker(
              markerId: const MarkerId('currentLocation'),
              position: latLng,
              infoWindow: const InfoWindow(title: 'Current Location'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
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
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              markers: _markers,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
            ),

        // Map control buttons overlay
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            children: [
              FloatingActionButton(
                heroTag: 'refreshLocation',
                mini: true,
                onPressed: () async {
                  await _getCurrentLocation();
                  await _animateToCurrentLocation();
                },
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.my_location,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8),
            ],
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
