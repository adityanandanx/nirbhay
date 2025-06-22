import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_advanced/sms_advanced.dart';
import 'dart:convert';
import '../models/emergency_contact.dart';
import 'ble_provider.dart';
import 'settings_provider.dart';

// Safety State Model
class SafetyState {
  final bool isSafetyModeActive;
  final Position? currentLocation;
  final bool isLocationTracking;
  final bool isEmergencyActive;
  final DateTime? lastEmergencyTime;
  final List<EmergencyContact> emergencyContacts;
  final bool isLoading;
  final String? error;

  const SafetyState({
    this.isSafetyModeActive = false,
    this.currentLocation,
    this.isLocationTracking = false,
    this.isEmergencyActive = false,
    this.lastEmergencyTime,
    this.emergencyContacts = const [],
    this.isLoading = false,
    this.error,
  });

  SafetyState copyWith({
    bool? isSafetyModeActive,
    Position? currentLocation,
    bool? isLocationTracking,
    bool? isEmergencyActive,
    DateTime? lastEmergencyTime,
    List<EmergencyContact>? emergencyContacts,
    bool? isLoading,
    String? error,
  }) {
    return SafetyState(
      isSafetyModeActive: isSafetyModeActive ?? this.isSafetyModeActive,
      currentLocation: currentLocation ?? this.currentLocation,
      isLocationTracking: isLocationTracking ?? this.isLocationTracking,
      isEmergencyActive: isEmergencyActive ?? this.isEmergencyActive,
      lastEmergencyTime: lastEmergencyTime ?? this.lastEmergencyTime,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  String get safetyStatus {
    if (isEmergencyActive) return 'Emergency Active';
    if (isSafetyModeActive) return 'Protected';
    return 'Inactive';
  }
}

// Safety State Notifier
class SafetyStateNotifier extends StateNotifier<SafetyState> {
  SafetyStateNotifier(this._bleStateNotifier, this._settingsNotifier)
    : super(const SafetyState()) {
    _init();
  }

  final BLEStateNotifier _bleStateNotifier;
  final SettingsStateNotifier _settingsNotifier;
  StreamSubscription<BLEState>? _bleStateSubscription;

  void _init() async {
    // Load emergency contacts from persistent storage
    await _loadEmergencyContacts();

    // Add default contacts if none exist (for demo purposes)
    if (state.emergencyContacts.isEmpty) {
      _addDefaultContacts();
    }

    // Listen to BLE state changes for sensor data and connection status
    _bleStateSubscription = _bleStateNotifier.stream.listen((bleState) {
      // If safety mode is active but device disconnected, show warning but keep safety mode active
      if (state.isSafetyModeActive && !bleState.isConnected) {
        state = state.copyWith(
          error:
              'Warning: Wearable device disconnected. Safety mode continues with phone-only features.',
        );
      }

      // Check sensor data for automatic threat detection (only if device is connected)
      if (bleState.sensorData != null &&
          state.isSafetyModeActive &&
          bleState.isConnected) {
        detectPotentialThreat(bleState.sensorData!);
      }
    });
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

      // Start/stop location tracking based on safety mode
      if (newState) {
        await _startLocationTracking();
      } else {
        await _stopLocationTracking();
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isSafetyModeActive: !newState, // Revert on error
        isLoading: false,
        error: 'Failed to toggle safety mode: ${e.toString()}',
      );
    }
  }

  Future<void> _startLocationTracking() async {
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

      state = state.copyWith(
        currentLocation: position,
        isLocationTracking: true,
      );

      // Start listening to location updates
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen((Position position) {
        state = state.copyWith(currentLocation: position);
      });
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to start location tracking: ${e.toString()}',
      );
    }
  }

  Future<void> _stopLocationTracking() async {
    state = state.copyWith(isLocationTracking: false, currentLocation: null);
  }

  Future<void> triggerEmergencyAlert() async {
    state = state.copyWith(
      isEmergencyActive: true,
      lastEmergencyTime: DateTime.now(),
      isLoading: true,
    );

    try {
      // Send emergency alert to BLE device
      // await _bleStateNotifier.sendEmergencyAlert();

      // Get current location for emergency
      if (state.currentLocation == null) {
        final position = await Geolocator.getCurrentPosition();
        state = state.copyWith(currentLocation: position);
      }

      await _sendEmergencyNotifications();

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to send emergency alert: ${e.toString()}',
      );
    }
  }

  Future<void> _sendEmergencyNotifications() async {
    final settings = _settingsNotifier.state;

    // Only proceed if emergency alerts are enabled
    if (!settings.emergencyAlertsEnabled) {
      return;
    }

    try {
      // Make direct call to topmost priority emergency contact first
      // but only if emergency alerts are enabled
      // if (state.emergencyContacts.isNotEmpty &&
      //     settings.emergencyAlertsEnabled) {
      //   await _callTopPriorityContact();
      // }

      // Send SMS to emergency contacts if enabled and contacts exist
      if (state.emergencyContacts.isNotEmpty) {
        await _sendEmergencySMS();
      }

      // Send push notifications if enabled
      await _sendEmergencyPushNotifications();

      // Log the emergency event if data backup is enabled
      if (settings.dataBackupEnabled) {
        await _logEmergencyEvent();
      }

      // Trigger device vibration if enabled
      if (settings.vibrationEnabled) {
        await _triggerEmergencyVibration();
      }

      // Play emergency sound if enabled
      if (settings.soundEnabled) {
        await _playEmergencySound();
      }
    } catch (e) {
      state = state.copyWith(
        error: 'Emergency notification failed: ${e.toString()}',
      );
    }
  }

  Future<void> _sendEmergencySMS() async {
    final currentLocation = state.currentLocation;
    final locationText =
        currentLocation != null
            ? 'Location: https://maps.google.com/?q=${currentLocation.latitude},${currentLocation.longitude}'
            : 'Location: Unable to determine location';

    final emergencyMessage = '''
🚨 EMERGENCY ALERT 🚨

This is an automated emergency alert from Nirbhay Safety App.

Time: ${DateTime.now().toString()}
$locationText

Please check on the user immediately or contact emergency services.

- Sent by Nirbhay Safety System
''';

    try {
      final SmsSender sender = SmsSender();
      final activeContacts =
          state.emergencyContacts.where((c) => c.isActive).toList();

      List<String> successfulSends = [];
      List<String> failedSends = [];

      for (final contact in activeContacts) {
        try {
          debugPrint(
            '📱 Sending emergency SMS to ${contact.name} (${contact.phone})',
          );

          final SmsMessage message = SmsMessage(
            contact.phone,
            emergencyMessage,
          );
          await sender.sendSms(message);

          successfulSends.add(contact.name);
          debugPrint('✅ Emergency SMS sent successfully to ${contact.name}');

          // Log the successful SMS if data backup is enabled
          final settings = _settingsNotifier.state;
          if (settings.dataBackupEnabled) {
            await _logEmergencySMS(contact, true);
          }
        } catch (e) {
          failedSends.add(contact.name);
          debugPrint('❌ Failed to send emergency SMS to ${contact.name}: $e');

          // Log the failure if data backup is enabled
          final settings = _settingsNotifier.state;
          if (settings.dataBackupEnabled) {
            await _logEmergencySMS(contact, false, error: e.toString());
          }
        }
      }

      // Update state with SMS sending results
      if (failedSends.isNotEmpty && successfulSends.isEmpty) {
        state = state.copyWith(
          error:
              'Failed to send emergency SMS to all contacts: ${failedSends.join(', ')}',
        );
      } else if (failedSends.isNotEmpty) {
        state = state.copyWith(
          error:
              'Emergency SMS sent to ${successfulSends.join(', ')}, but failed for ${failedSends.join(', ')}',
        );
      } else {
        debugPrint(
          '✅ Emergency SMS sent successfully to all active contacts: ${successfulSends.join(', ')}',
        );
      }
    } catch (e) {
      debugPrint('🚨 Critical error during emergency SMS sending: $e');
      state = state.copyWith(
        error: 'Critical failure sending emergency SMS: ${e.toString()}',
      );
    }
  }

  Future<void> _sendEmergencyPushNotifications() async {
    // TODO: Implement push notification sending
    // This would use Firebase Cloud Messaging or similar service
    debugPrint('Emergency push notifications would be sent');
  }

  Future<void> _logEmergencyEvent() async {
    // TODO: Implement emergency event logging
    // This would save to local database and/or cloud storage
    final emergencyLog = {
      'timestamp': DateTime.now().toIso8601String(),
      'location':
          state.currentLocation != null
              ? {
                'latitude': state.currentLocation!.latitude,
                'longitude': state.currentLocation!.longitude,
              }
              : null,
      'emergency_contacts_notified':
          state.emergencyContacts.map((c) => c.name).toList(),
      'user_triggered': true, // Could be false for automatic detection
    };

    debugPrint('Emergency event logged: $emergencyLog');
  }

  Future<void> _triggerEmergencyVibration() async {
    // TODO: Implement device vibration
    // This would use HapticFeedback or vibration plugin
    debugPrint('Emergency vibration triggered');
  }

  Future<void> _playEmergencySound() async {
    // TODO: Implement emergency sound
    // This would use audioplayers or similar plugin
    debugPrint('Emergency sound would play');
  }

  Future<void> cancelEmergencyAlert() async {
    state = state.copyWith(isEmergencyActive: false, isLoading: true);

    try {
      final settings = _settingsNotifier.state;

      // Only send cancellation notifications if emergency alerts are enabled
      if (settings.emergencyAlertsEnabled &&
          state.emergencyContacts.isNotEmpty) {
        await _sendEmergencyCancellationSMS();
      }

      // Log cancellation if data backup is enabled
      if (settings.dataBackupEnabled) {
        await _logEmergencyCancellation();
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to cancel emergency alert: ${e.toString()}',
      );
    }
  }

  Future<void> _sendEmergencyCancellationSMS() async {
    final cancellationMessage = '''
✅ EMERGENCY CANCELLED ✅

The emergency alert has been cancelled by the user.

Time: ${DateTime.now().toString()}

The user is now safe.

- Sent by Nirbhay Safety System
''';

    try {
      final SmsSender sender = SmsSender();
      final activeContacts =
          state.emergencyContacts.where((c) => c.isActive).toList();

      List<String> successfulSends = [];
      List<String> failedSends = [];

      for (final contact in activeContacts) {
        try {
          debugPrint(
            '📱 Sending emergency cancellation SMS to ${contact.name} (${contact.phone})',
          );

          final SmsMessage message = SmsMessage(
            contact.phone,
            cancellationMessage,
          );
          await sender.sendSms(message);

          successfulSends.add(contact.name);
          debugPrint(
            '✅ Emergency cancellation SMS sent successfully to ${contact.name}',
          );

          // Log the successful SMS if data backup is enabled
          final settings = _settingsNotifier.state;
          if (settings.dataBackupEnabled) {
            await _logEmergencyCancellationSMS(contact, true);
          }
        } catch (e) {
          failedSends.add(contact.name);
          debugPrint(
            '❌ Failed to send emergency cancellation SMS to ${contact.name}: $e',
          );

          // Log the failure if data backup is enabled
          final settings = _settingsNotifier.state;
          if (settings.dataBackupEnabled) {
            await _logEmergencyCancellationSMS(
              contact,
              false,
              error: e.toString(),
            );
          }
        }
      }

      // Log results
      if (successfulSends.isNotEmpty) {
        debugPrint(
          '✅ Emergency cancellation SMS sent successfully to: ${successfulSends.join(', ')}',
        );
      }
      if (failedSends.isNotEmpty) {
        debugPrint(
          '❌ Failed to send emergency cancellation SMS to: ${failedSends.join(', ')}',
        );
      }
    } catch (e) {
      debugPrint(
        '🚨 Critical error during emergency cancellation SMS sending: $e',
      );
    }
  }

  Future<void> _logEmergencyCancellation() async {
    // TODO: Implement emergency cancellation logging
    final cancellationLog = {
      'timestamp': DateTime.now().toIso8601String(),
      'original_emergency_time': state.lastEmergencyTime?.toIso8601String(),
      'cancelled_by_user': true,
    };

    debugPrint('Emergency cancellation logged: $cancellationLog');
  }

  void addEmergencyContact(EmergencyContact contact) {
    final updatedContacts = [...state.emergencyContacts, contact];
    state = state.copyWith(emergencyContacts: updatedContacts);
    _saveEmergencyContacts();
  }

  void removeEmergencyContact(String contactId) {
    final updatedContacts =
        state.emergencyContacts.where((c) => c.id != contactId).toList();
    state = state.copyWith(emergencyContacts: updatedContacts);
    _saveEmergencyContacts();
  }

  void updateEmergencyContact(EmergencyContact updatedContact) {
    final updatedContacts =
        state.emergencyContacts.map((contact) {
          return contact.id == updatedContact.id ? updatedContact : contact;
        }).toList();
    state = state.copyWith(emergencyContacts: updatedContacts);
    _saveEmergencyContacts();
  }

  Future<void> _loadEmergencyContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactsJson = prefs.getStringList('emergency_contacts') ?? [];

      final contacts =
          contactsJson.map((jsonStr) {
            final json = jsonDecode(jsonStr) as Map<String, dynamic>;
            return EmergencyContact.fromJson(json);
          }).toList();

      state = state.copyWith(emergencyContacts: contacts);
    } catch (e) {
      debugPrint('Error loading emergency contacts: $e');
    }
  }

  Future<void> _saveEmergencyContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactsJson =
          state.emergencyContacts
              .map((contact) => jsonEncode(contact.toJson()))
              .toList();

      await prefs.setStringList('emergency_contacts', contactsJson);
    } catch (e) {
      debugPrint('Error saving emergency contacts: $e');
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _bleStateSubscription?.cancel();
    super.dispose();
  }

  // Automatic threat detection based on sensor data
  Future<void> detectPotentialThreat(Map<String, dynamic> sensorData) async {
    final settings = _settingsNotifier.state;

    // Only proceed if automatic detection is enabled
    if (!settings.automaticDetectionEnabled || !state.isSafetyModeActive) {
      return;
    }

    // Analyze sensor data for threat patterns
    bool threatDetected = _analyzeSensorData(
      sensorData,
      settings.alertSensitivity,
    );

    if (threatDetected) {
      // Start countdown before triggering emergency alert
      await _startEmergencyCountdown();
    }
  }

  bool _analyzeSensorData(Map<String, dynamic> sensorData, String sensitivity) {
    // TODO: Implement actual threat detection algorithm
    // This would analyze heart rate, movement patterns, etc.
    // Sensitivity levels: "Low", "Medium", "High"

    // Example logic (placeholder):
    final heartRate = sensorData['heart_rate'] as int? ?? 0;
    final suddenMovement = sensorData['sudden_movement'] as bool? ?? false;
    final impactDetected = sensorData['impact_detected'] as bool? ?? false;

    switch (sensitivity) {
      case 'Low':
        return impactDetected && heartRate > 120;
      case 'Medium':
        return (impactDetected && heartRate > 110) ||
            (suddenMovement && heartRate > 130);
      case 'High':
        return impactDetected || (suddenMovement && heartRate > 100);
      default:
        return false;
    }
  }

  Future<void> _startEmergencyCountdown() async {
    final settings = _settingsNotifier.state;

    // Start countdown based on settings
    state = state.copyWith(
      error:
          'Potential threat detected! Emergency alert will trigger in ${settings.sosCountdownTime} seconds. Tap to cancel.',
    );

    // TODO: Implement actual countdown with user interaction
    // This would show a countdown dialog/screen where user can cancel
    await Future.delayed(Duration(seconds: settings.sosCountdownTime));

    // If not cancelled by user, trigger emergency alert
    if (state.error != null &&
        state.error!.contains('Potential threat detected')) {
      await triggerEmergencyAlert();
    }
  }

  Future<void> _callTopPriorityContact() async {
    // Validate that we have emergency contacts
    if (state.emergencyContacts.isEmpty) {
      debugPrint('❌ No emergency contacts available for calling');
      state = state.copyWith(
        error:
            'No emergency contacts configured. Please add emergency contacts in settings.',
      );
      return;
    }

    try {
      // Get active contacts sorted by priority
      final activeContacts =
          state.emergencyContacts.where((contact) => contact.isActive).toList()
            ..sort((a, b) => a.priority.compareTo(b.priority));

      if (activeContacts.isEmpty) {
        debugPrint('❌ No active emergency contacts available for calling');
        state = state.copyWith(
          error:
              'No active emergency contacts configured. Please activate emergency contacts in settings.',
        );
        return;
      }

      // Get the first (highest priority) emergency contact
      final topPriorityContact = activeContacts.first;

      // Validate the phone number format (basic validation)
      if (!_isValidPhoneNumber(topPriorityContact.phone)) {
        debugPrint(
          '❌ Invalid phone number format: ${topPriorityContact.phone}',
        );
        state = state.copyWith(
          error:
              'Invalid emergency contact number. Please check your emergency contacts.',
        );
        return;
      }

      debugPrint(
        '📞 Attempting emergency call to top priority contact: ${topPriorityContact.name} (${topPriorityContact.phone})',
      );

      // Attempt to make the direct call
      bool? callResult = await FlutterPhoneDirectCaller.callNumber(
        topPriorityContact.phone,
      );

      if (callResult == true) {
        debugPrint(
          '✅ Emergency call successfully initiated to: ${topPriorityContact.name}',
        );

        // Log the successful call attempt if data backup is enabled
        final settings = _settingsNotifier.state;
        if (settings.dataBackupEnabled) {
          await _logEmergencyCall(topPriorityContact, true);
        }
      } else {
        debugPrint(
          '❌ Failed to initiate emergency call to: ${topPriorityContact.name}',
        );

        // Try calling the next contact if available
        if (activeContacts.length > 1) {
          await _trySecondaryEmergencyCall(activeContacts);
        }

        // Log the failure
        final settings = _settingsNotifier.state;
        if (settings.dataBackupEnabled) {
          await _logEmergencyCall(topPriorityContact, false);
        }

        // Set a non-critical error (don't stop other emergency actions)
        state = state.copyWith(
          error:
              'Unable to place emergency call to primary contact. SMS and other alerts are still being sent.',
        );
      }
    } catch (e) {
      debugPrint('🚨 Error during emergency call: $e');

      // Try secondary contact if available
      final activeContacts =
          state.emergencyContacts.where((contact) => contact.isActive).toList()
            ..sort((a, b) => a.priority.compareTo(b.priority));

      if (activeContacts.length > 1) {
        await _trySecondaryEmergencyCall(activeContacts);
      }

      // Don't let call failure stop other emergency notifications
      state = state.copyWith(
        error:
            'Emergency call failed: ${e.toString()}. Other alerts are still being sent.',
      );
    }
  }

  Future<void> _trySecondaryEmergencyCall(
    List<EmergencyContact> activeContacts,
  ) async {
    if (activeContacts.length < 2) return;

    try {
      final secondaryContact = activeContacts[1];
      debugPrint(
        'Trying secondary emergency contact: ${secondaryContact.name} (${secondaryContact.phone})',
      );

      bool? callResult = await FlutterPhoneDirectCaller.callNumber(
        secondaryContact.phone,
      );

      if (callResult == true) {
        debugPrint(
          '✅ Emergency call successfully initiated to secondary contact: ${secondaryContact.name}',
        );

        final settings = _settingsNotifier.state;
        if (settings.dataBackupEnabled) {
          await _logEmergencyCall(secondaryContact, true, isSecondary: true);
        }
      } else {
        debugPrint(
          '❌ Failed to call secondary contact: ${secondaryContact.name}',
        );

        final settings = _settingsNotifier.state;
        if (settings.dataBackupEnabled) {
          await _logEmergencyCall(secondaryContact, false, isSecondary: true);
        }
      }
    } catch (e) {
      debugPrint('🚨 Error calling secondary contact: $e');
    }
  }

  Future<void> _logEmergencyCall(
    EmergencyContact contact,
    bool success, {
    bool isSecondary = false,
  }) async {
    final callLog = {
      'timestamp': DateTime.now().toIso8601String(),
      'contact_id': contact.id,
      'contact_name': contact.name,
      'contact_phone': contact.phone,
      'contact_relationship': contact.relationship,
      'call_successful': success,
      'is_secondary_contact': isSecondary,
      'call_type': 'emergency_auto_call',
    };

    debugPrint('Emergency call logged: $callLog');
  }

  Future<void> _logEmergencySMS(
    EmergencyContact contact,
    bool success, {
    String? error,
  }) async {
    final smsLog = {
      'timestamp': DateTime.now().toIso8601String(),
      'contact_id': contact.id,
      'contact_name': contact.name,
      'contact_phone': contact.phone,
      'contact_relationship': contact.relationship,
      'sms_successful': success,
      'sms_type': 'emergency_alert',
      if (error != null) 'error': error,
    };

    debugPrint('Emergency SMS logged: $smsLog');
  }

  Future<void> _logEmergencyCancellationSMS(
    EmergencyContact contact,
    bool success, {
    String? error,
  }) async {
    final smsLog = {
      'timestamp': DateTime.now().toIso8601String(),
      'contact_id': contact.id,
      'contact_name': contact.name,
      'contact_phone': contact.phone,
      'contact_relationship': contact.relationship,
      'sms_successful': success,
      'sms_type': 'emergency_cancellation',
      if (error != null) 'error': error,
    };

    debugPrint('Emergency cancellation SMS logged: $smsLog');
  }

  /// Validates if a phone number has a basic valid format
  /// This is a simple validation - you might want to use a more robust solution
  bool _isValidPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters for validation
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Check if it has at least 7 digits and at most 15 digits (international standard)
    if (digitsOnly.length < 7 || digitsOnly.length > 15) {
      return false;
    }

    // Check if the original contains valid phone characters
    final validChars = RegExp(r'^[\d\s\+\(\)\-\.]+$');
    return validChars.hasMatch(phoneNumber);
  }

  void _addDefaultContacts() {
    final defaultContacts = [
      EmergencyContact(
        id: 'default_1',
        name: 'Mom',
        phone: '+1 234 567 8900',
        relationship: 'Family',
        isActive: true,
        priority: 1,
      ),
      EmergencyContact(
        id: 'default_2',
        name: 'Dad',
        phone: '+1 234 567 8901',
        relationship: 'Family',
        isActive: true,
        priority: 2,
      ),
      EmergencyContact(
        id: 'default_3',
        name: 'Best Friend Sarah',
        phone: '+1 234 567 8902',
        relationship: 'Friend',
        isActive: false,
        priority: 3,
      ),
    ];

    state = state.copyWith(emergencyContacts: defaultContacts);
    _saveEmergencyContacts();
  }

  /// Send a custom SMS to all active emergency contacts
  Future<bool> sendCustomSMSToEmergencyContacts(String message) async {
    try {
      final SmsSender sender = SmsSender();
      final activeContacts =
          state.emergencyContacts.where((c) => c.isActive).toList();

      if (activeContacts.isEmpty) {
        debugPrint('❌ No active emergency contacts to send SMS to');
        state = state.copyWith(
          error: 'No active emergency contacts configured for SMS sending.',
        );
        return false;
      }

      List<String> successfulSends = [];
      List<String> failedSends = [];

      for (final contact in activeContacts) {
        try {
          debugPrint(
            '📱 Sending custom SMS to ${contact.name} (${contact.phone})',
          );

          final SmsMessage smsMessage = SmsMessage(contact.phone, message);
          await sender.sendSms(smsMessage);

          successfulSends.add(contact.name);
          debugPrint('✅ Custom SMS sent successfully to ${contact.name}');
        } catch (e) {
          failedSends.add(contact.name);
          debugPrint('❌ Failed to send custom SMS to ${contact.name}: $e');
        }
      }

      // Log results
      if (successfulSends.isNotEmpty) {
        debugPrint(
          '✅ Custom SMS sent successfully to: ${successfulSends.join(', ')}',
        );
      }
      if (failedSends.isNotEmpty) {
        debugPrint('❌ Failed to send custom SMS to: ${failedSends.join(', ')}');
        state = state.copyWith(
          error:
              'SMS sent to ${successfulSends.join(', ')}, but failed for ${failedSends.join(', ')}',
        );
      }

      return failedSends.isEmpty;
    } catch (e) {
      debugPrint('🚨 Critical error during custom SMS sending: $e');
      state = state.copyWith(error: 'Failed to send SMS: ${e.toString()}');
      return false;
    }
  }

  /// Send SMS to a specific emergency contact
  Future<bool> sendSMSToContact(String contactId, String message) async {
    try {
      final contact = state.emergencyContacts.firstWhere(
        (c) => c.id == contactId,
        orElse: () => throw Exception('Contact not found'),
      );

      if (!contact.isActive) {
        debugPrint('❌ Cannot send SMS to inactive contact: ${contact.name}');
        state = state.copyWith(
          error: 'Cannot send SMS to inactive contact: ${contact.name}',
        );
        return false;
      }

      final SmsSender sender = SmsSender();
      debugPrint('📱 Sending SMS to ${contact.name} (${contact.phone})');

      final SmsMessage smsMessage = SmsMessage(contact.phone, message);
      await sender.sendSms(smsMessage);

      debugPrint('✅ SMS sent successfully to ${contact.name}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to send SMS: $e');
      state = state.copyWith(error: 'Failed to send SMS: ${e.toString()}');
      return false;
    }
  }
}
