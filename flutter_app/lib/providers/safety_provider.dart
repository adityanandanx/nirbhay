import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/emergency_contact.dart';
import '../models/safety_state.dart';
import '../services/contact_service.dart';
import '../services/emergency_service.dart';
import '../services/location_service.dart';
import '../services/distress_audio_detection_service.dart';
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
  late final DistressAudioDetectionService _distressDetectionService;

  StreamSubscription<BLEState>? _bleStateSubscription;

  Timer? _emergencyCountdownTimer;

  void _init() async {
    // Initialize services
    _contactService = ContactService();
    _locationService = LocationService();
    _emergencyService = EmergencyService(_settingsNotifier.state);
    _distressDetectionService = DistressAudioDetectionService();

    // Initialize distress detection service and set up emergency detection callback
    await _initDistressDetection();

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

      // Check for emergency cancel signal
      if (bleState.sensorData != null &&
          bleState.sensorData!['emergency_cancelled'] == true) {
        cancelEmergencyCountdown();
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

      bool voiceDetectionActive = false;

      // Start/stop distress detection based on safety mode and settings
      if (newState && _settingsNotifier.state.voiceDetectionEnabled) {
        await _distressDetectionService.startListening();
        voiceDetectionActive = true;
        debugPrint('✅ Distress detection started');
      } else if (!newState) {
        await _distressDetectionService.stopListening();
        debugPrint('✅ Distress detection stopped');
      }

      // Start/stop location tracking based on safety mode
      if (newState) {
        state = await _locationService.startLocationTracking(state);
      } else {
        state = _locationService.stopLocationTracking(state);
      }

      state = state.copyWith(
        isLoading: false,
        isVoiceDetectionActive: newState && voiceDetectionActive,
      );
    } catch (e) {
      state = state.copyWith(
        isSafetyModeActive: !newState, // Revert on error
        isLoading: false,
        isVoiceDetectionActive: false,
        error: 'Failed to toggle safety mode: ${e.toString()}',
      );
    }
  }

  // Lock to prevent multiple simultaneous emergency triggers
  bool _isTriggering = false;
  // Lock to prevent multiple simultaneous countdowns
  bool _isCountdownActive = false;
  // Timestamp of the last emergency trigger
  DateTime? _lastEmergencyTriggerTime;
  // Cooldown period between emergency triggers
  static const Duration _emergencyCooldown = Duration(seconds: 20);

  Future<void> triggerEmergencyAlert() async {
    final now = DateTime.now();

    // Check if already in emergency state
    if (state.isEmergencyActive) {
      debugPrint('⚠️ Emergency already active, ignoring trigger');
      return;
    }

    // Check cooldown period
    if (_lastEmergencyTriggerTime != null) {
      final timeSinceLastTrigger = now.difference(_lastEmergencyTriggerTime!);
      if (timeSinceLastTrigger < _emergencyCooldown) {
        debugPrint(
          '🕒 Emergency cooldown period active (${timeSinceLastTrigger.inSeconds}s), ignoring trigger',
        );
        return;
      }
    }

    // Prevent multiple simultaneous triggers
    if (_isTriggering) {
      debugPrint('⚠️ Already triggering emergency, ignoring duplicate call');
      return;
    }

    _isTriggering = true;

    try {
      debugPrint('🚨 TRIGGERING EMERGENCY ALERT');
      _lastEmergencyTriggerTime = now;

      // Get current location for emergency if not already tracking
      Position? currentLocation;
      if (state.currentLocation == null) {
        try {
          currentLocation = await _locationService.getCurrentLocation();
        } catch (e) {
          debugPrint('⚠️ Failed to get location for emergency: $e');
          // Continue without location
        }
      }

      // Trigger emergency through the service
      state = await _emergencyService.triggerEmergencyAlert(
        state,
        currentLocation,
      );

      debugPrint('✅ Emergency alert triggered successfully');
    } catch (e) {
      debugPrint('❌ Failed to trigger emergency alert: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to send emergency alert: ${e.toString()}',
      );
    } finally {
      _isTriggering = false;
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
        await startEmergencyCountdown();
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
  void dispose() async {
    _bleStateSubscription?.cancel();
    await _distressDetectionService.dispose();
    super.dispose();
  }

  /// Initialize distress detection service
  Future<void> _initDistressDetection() async {
    try {
      // Initialize the distress detection service with emergency callback
      await _distressDetectionService.initialize(
        onDistressDetected: () async {
          // Only trigger if safety mode is active and not already in emergency
          if (state.isSafetyModeActive && !state.isEmergencyActive) {
            try {
              debugPrint('🚨 Emergency detected through distress sound!');
              await startEmergencyCountdown();
            } catch (e) {
              debugPrint('❌ Failed to handle distress-triggered emergency: $e');
            }
          }
        },
        onError: (error) {
          debugPrint('❌ Distress detection error: $error');
          state = state.copyWith(error: 'Distress detection error: $error');
        },
      );
      debugPrint('✅ Distress detection service initialized');
    } catch (e) {
      debugPrint('❌ Distress detection initialization failed: $e');
      state = state.copyWith(
        error: 'Failed to initialize distress detection: ${e.toString()}',
      );
    }
  }

  /// Start emergency countdown and wait for cancel signal
  Future<void> startEmergencyCountdown() async {
    debugPrint('🕒 Starting emergency countdown (active: $_isCountdownActive)');
    if (_isCountdownActive) {
      debugPrint('⚠️ Emergency countdown already in progress');
      return;
    }

    if (state.isEmergencyActive) {
      debugPrint('⚠️ Emergency already active, ignoring countdown');
      return;
    }

    try {
      _isCountdownActive = true;
      debugPrint('✅ Emergency countdown activated');

      // Get countdown duration from settings
      final countdownDuration = _settingsNotifier.state.sosCountdownTime;

      // Send timer signal to device
      if (_bleStateNotifier.mounted && _bleStateNotifier.state.isConnected) {
        try {
          await _bleStateNotifier.sendEmergencyTimer(countdownDuration);
        } catch (e) {
          debugPrint('Failed to send emergency timer to device: $e');
          // Continue with countdown even if device notification fails
        }
      }

      // Start local countdown
      _emergencyCountdownTimer?.cancel();
      _emergencyCountdownTimer = Timer(
        Duration(seconds: countdownDuration),
        () async {
          _isCountdownActive = false; // Reset countdown flag
          // Timer completed without receiving cancel signal
          await triggerEmergencyAlert();
        },
      );

      // Update state to show countdown is active
      state = state.copyWith(
        isEmergencyCountdownActive: true,
        emergencyCountdownStartTime: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Failed to start emergency countdown: $e');
      _isCountdownActive = false; // Reset countdown flag on error
      state = state.copyWith(
        error: 'Failed to start emergency countdown: ${e.toString()}',
        isEmergencyCountdownActive: false,
        emergencyCountdownStartTime: null,
      );
    }
  }

  /// Cancel the emergency countdown
  void cancelEmergencyCountdown() {
    debugPrint('🛑 Cancelling emergency countdown');
    _emergencyCountdownTimer?.cancel();
    _emergencyCountdownTimer = null;
    _isCountdownActive = false;
    state = state.copyWith(
      isEmergencyCountdownActive: false,
      emergencyCountdownStartTime: null,
    );
    debugPrint('✅ Emergency countdown cancelled');
  }
}
