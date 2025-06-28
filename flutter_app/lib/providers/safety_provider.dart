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
import '../services/fight_flight_predictor.dart';
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

  // Fight/Flight prediction variables
  Timer? _predictionTimer;
  final List<List<double>> _sensorDataBuffer = [];
  late final FightFlightPredictor _predictor;
  bool _isPredictorInitialized = false;

  void _init() async {
    // Initialize services
    _contactService = ContactService();
    _locationService = LocationService();
    _emergencyService = EmergencyService(_settingsNotifier.state);
    _distressDetectionService = DistressAudioDetectionService();

    // Initialize fight/flight predictor
    await _initPredictor();

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

      // Process sensor data for predictions and threat detection
      if (bleState.sensorData != null &&
          state.isSafetyModeActive &&
          bleState.isConnected) {
        _processSensorData(bleState.sensorData!);
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

      // Cancel any active countdown since we're triggering the emergency now
      cancelEmergencyCountdown();

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
      // Check for demo mode atypical flag
      if (sensorData['demo_atypical'] == true) {
        debugPrint('⚠️ Demo mode atypical behavior detected');
        // Start distress audio detection
        if (!_distressDetectionService.isListening) {
          debugPrint('🎤 Starting distress audio detection in demo mode');
          await _distressDetectionService.startListening();
        }
        state = state.copyWith(
          error: 'Demo Mode: Monitoring for distress signals',
        );
        return;
      }

      // Normal threat detection for non-demo mode
      final updatedState = await _emergencyService.detectPotentialThreat(
        state,
        sensorData,
      );

      // Update state if there's a detected threat
      if (updatedState.error != null &&
          updatedState.error!.contains('Potential threat detected')) {
        state = updatedState;
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
    _predictionTimer?.cancel();
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
            debugPrint('🚨 Emergency detected through distress sound!');
            await startEmergencyCountdown();
          }
        },
        onSpeechRecognized: (speech) {
          debugPrint('🗣️ Speech recognized: $speech');
        },
        onError: (error) {
          debugPrint('❌ Distress detection error: $error');
          state = state.copyWith(
            error: 'Distress detection error: $error',
          );
        },
        onSoundDetected: (label, confidence) {
          // Update state with the latest detected sound
          state = state.copyWith(
            detectedSound: (label, confidence),
          );
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

  /// Initialize fight/flight predictor
  Future<void> _initPredictor() async {
    if (_isPredictorInitialized) return;

    try {
      _predictor = FightFlightPredictor();
      await _predictor.load();
      _isPredictorInitialized = true;
      _setupPredictionTimer();
      debugPrint('✅ Fight/Flight predictor initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize fight/flight predictor: $e');
    }
  }

  /// Process sensor data for prediction
  void _processSensorData(Map<String, dynamic> data) {
    if (!_isPredictorInitialized) return;

    try {
      final List<double> sensorReading = [];

      // Add heart rate
      sensorReading.add(data['heartRate']?.toDouble() ?? 0.0);

      // Add accelerometer data
      if (data['accel'] != null) {
        sensorReading.add(data['accel']['x']?.toDouble() ?? 0.0);
        sensorReading.add(data['accel']['y']?.toDouble() ?? 0.0);
        sensorReading.add(data['accel']['z']?.toDouble() ?? 0.0);
      } else {
        sensorReading.addAll([0.0, 0.0, 0.0]);
      }

      // Add gyroscope data
      if (data['gyro'] != null) {
        sensorReading.add(data['gyro']['x']?.toDouble() ?? 0.0);
        sensorReading.add(data['gyro']['y']?.toDouble() ?? 0.0);
        sensorReading.add(data['gyro']['z']?.toDouble() ?? 0.0);
      } else {
        sensorReading.addAll([0.0, 0.0, 0.0]);
      }

      // Add to buffer
      _sensorDataBuffer.add(sensorReading);

      // Keep only the most recent 8 readings
      if (_sensorDataBuffer.length > 8) {
        _sensorDataBuffer.removeAt(0);
      }
    } catch (e) {
      debugPrint('Error processing sensor data: $e');
    }
  }

  /// Setup prediction timer
  void _setupPredictionTimer() {
    _predictionTimer?.cancel();
    _predictionTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _runPrediction(),
    );
  }

  /// Run fight/flight prediction
  Future<void> _runPrediction() async {
    // Only run prediction if safety mode is active and we have enough data
    if (!state.isSafetyModeActive || _sensorDataBuffer.length < 8) return;

    debugPrint('🔄 Running fight/flight prediction...');

    try {
      // Clone the buffer to avoid modification during prediction
      final batchData = List<List<double>>.from(_sensorDataBuffer);
      final result = await _predictor.predict(batchData);
      debugPrint("🔄 Fight/Flight prediction: $result");

      // Handle atypical behavior detection
      if (result.contains('Atypical')) {
        debugPrint('⚠️ Atypical behavior detected through sensors');

        // Start distress audio detection to confirm the emergency
        if (!_distressDetectionService.isListening) {
          debugPrint(
            '🎤 Starting distress audio detection due to atypical behavior',
          );
          await _distressDetectionService.startListening();
        }

        // Update state to show warning
        state = state.copyWith(
          error: 'Potential threat detected: Monitoring for distress signals',
        );
      }
    } catch (e) {
      debugPrint('❌ Error during fight/flight prediction: $e');
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
