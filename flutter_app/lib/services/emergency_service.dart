import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:geolocator/geolocator.dart';
import '../models/emergency_contact.dart';
import '../models/safety_state.dart';
import '../providers/settings_provider.dart';

/// Service for handling emergency alerts and related functionality
class EmergencyService {
  final Telephony _telephony = Telephony.instance;
  final SettingsState _settings;

  EmergencyService(this._settings);

  /// Trigger an emergency alert
  Future<SafetyState> triggerEmergencyAlert(
    SafetyState currentState,
    Position? currentLocation,
  ) async {
    final newState = currentState.copyWith(
      isEmergencyActive: true,
      lastEmergencyTime: DateTime.now(),
      isLoading: true,
    );

    try {
      // Update with current location if available and not already set
      Position? locationToUse = currentState.currentLocation ?? currentLocation;

      SafetyState updatedState = newState;
      if (locationToUse != null && currentState.currentLocation == null) {
        updatedState = updatedState.copyWith(currentLocation: locationToUse);
      }

      // Send emergency notifications
      await _sendEmergencyNotifications(updatedState);

      return updatedState.copyWith(isLoading: false);
    } catch (e) {
      return newState.copyWith(
        isLoading: false,
        error: 'Failed to send emergency alert: ${e.toString()}',
      );
    }
  }

  /// Cancel an emergency alert
  Future<SafetyState> cancelEmergencyAlert(SafetyState currentState) async {
    final newState = currentState.copyWith(
      isEmergencyActive: false,
      isLoading: true,
    );

    try {
      // Only send cancellation notifications if emergency alerts are enabled
      if (_settings.emergencyAlertsEnabled &&
          currentState.emergencyContacts.isNotEmpty) {
        await _sendEmergencyCancellationSMS(currentState.emergencyContacts);
      }

      // Log cancellation if data backup is enabled
      if (_settings.dataBackupEnabled) {
        await _logEmergencyCancellation(currentState.lastEmergencyTime);
      }

      return newState.copyWith(isLoading: false);
    } catch (e) {
      return newState.copyWith(
        isLoading: false,
        error: 'Failed to cancel emergency alert: ${e.toString()}',
      );
    }
  }

  /// Analyze sensor data for threats
  bool analyzeSensorData(Map<String, dynamic> sensorData, String sensitivity) {
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

  /// Detect potential threats from sensor data
  Future<SafetyState> detectPotentialThreat(
    SafetyState currentState,
    Map<String, dynamic> sensorData,
  ) async {
    // Only proceed if automatic detection is enabled
    if (!_settings.automaticDetectionEnabled ||
        !currentState.isSafetyModeActive) {
      return currentState;
    }

    // Analyze sensor data for threat patterns
    bool threatDetected = analyzeSensorData(
      sensorData,
      _settings.alertSensitivity,
    );

    if (threatDetected) {
      // Notify about detected threat with countdown info
      return currentState.copyWith(
        error:
            'Potential threat detected! Emergency alert will trigger in ${_settings.sosCountdownTime} seconds. Tap to cancel.',
      );
    }

    return currentState;
  }

  /// Send emergency SMS to all active contacts
  Future<void> _sendEmergencyNotifications(SafetyState state) async {
    // Only proceed if emergency alerts are enabled
    if (!_settings.emergencyAlertsEnabled) {
      return;
    }

    try {
      // Make direct call to topmost priority emergency contact first
      if (state.emergencyContacts.isNotEmpty &&
          _settings.emergencyAlertsEnabled) {
        await _callTopPriorityContact(state.emergencyContacts);
      }

      // Send SMS to emergency contacts if enabled and contacts exist
      if (state.emergencyContacts.isNotEmpty) {
        await _sendEmergencySMS(state.emergencyContacts, state.currentLocation);
      }

      // Send push notifications if enabled
      await _sendEmergencyPushNotifications();

      // Log the emergency event if data backup is enabled
      if (_settings.dataBackupEnabled) {
        await _logEmergencyEvent(state);
      }

      // Trigger device vibration if enabled
      if (_settings.vibrationEnabled) {
        await _triggerEmergencyVibration();
      }

      // Play emergency sound if enabled
      if (_settings.soundEnabled) {
        await _playEmergencySound();
      }
    } catch (e) {
      debugPrint('Emergency notification error: $e');
      // Let the error propagate to be handled by the caller
      rethrow;
    }
  }

  /// Send emergency SMS to all active contacts
  Future<void> _sendEmergencySMS(
    List<EmergencyContact> contacts,
    Position? currentLocation,
  ) async {
    final locationText =
        currentLocation != null
            ? 'Location: https://maps.google.com/?q=${currentLocation.latitude},${currentLocation.longitude}'
            : 'Location: Unable to determine location';

    final emergencyMessage = '''
🚨 EMERGENCY ALERT 🚨

${contacts.length > 1 ? 'This is an automated emergency alert from Nirbhay Safety App.' : 'This is an automated emergency alert.'}

Time: ${DateTime.now().toString()}
$locationText

Please check on the user immediately or contact emergency services.

- Sent by Nirbhay Safety System
''';

    try {
      // Request SMS permissions
      bool permissionsGranted =
          await _telephony.requestPhoneAndSmsPermissions ?? false;

      if (!permissionsGranted) {
        debugPrint('❌ SMS permissions not granted');
        throw Exception(
          'SMS permissions required to send emergency alerts. Please grant permissions in settings.',
        );
      }

      // Send SMS to all active emergency contacts
      final activeContacts =
          contacts.where((contact) => contact.isActive).toList();

      if (activeContacts.isEmpty) {
        debugPrint('❌ No active emergency contacts for SMS');
        return;
      }

      for (final contact in activeContacts) {
        try {
          debugPrint(
            '📱 Sending emergency SMS to: ${contact.name} (${contact.phone})',
          );
          await _telephony.sendSms(
            to: contact.phone,
            message: emergencyMessage,
            isMultipart: true,
            statusListener: (SendStatus status) {
              switch (status) {
                case SendStatus.SENT:
                  debugPrint('✅ SMS sent successfully to ${contact.name}');
                  break;
                case SendStatus.DELIVERED:
                  debugPrint('✅ SMS delivered to ${contact.name}');
                  break;
              }
            },
          );

          // Small delay between messages to avoid spam detection
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          debugPrint('❌ Failed to send SMS to ${contact.name}: $e');
          // Continue sending to other contacts even if one fails
        }
      }

      debugPrint('📱 Emergency SMS sending completed');
    } catch (e) {
      debugPrint('❌ Emergency SMS sending failed: $e');
      rethrow;
    }
  }

  /// Send cancellation SMS to all active contacts
  Future<void> _sendEmergencyCancellationSMS(
    List<EmergencyContact> contacts,
  ) async {
    final cancellationMessage = '''
✅ EMERGENCY CANCELLED ✅

The emergency alert has been cancelled by the user.

Time: ${DateTime.now().toString()}

The user is now safe.

- Sent by Nirbhay Safety System
''';

    try {
      // Check if SMS permissions are available
      bool permissionsGranted =
          await _telephony.requestPhoneAndSmsPermissions ?? false;

      if (!permissionsGranted) {
        debugPrint('❌ SMS permissions not granted for cancellation');
        return;
      }

      // Send cancellation SMS to all active emergency contacts
      final activeContacts =
          contacts.where((contact) => contact.isActive).toList();

      if (activeContacts.isEmpty) {
        debugPrint('❌ No active emergency contacts for cancellation SMS');
        return;
      }

      for (final contact in activeContacts) {
        try {
          debugPrint(
            '📱 Sending cancellation SMS to: ${contact.name} (${contact.phone})',
          );

          await _telephony.sendSms(
            to: contact.phone,
            message: cancellationMessage,
            isMultipart: true,
            statusListener: (SendStatus status) {
              switch (status) {
                case SendStatus.SENT:
                  debugPrint(
                    '✅ Cancellation SMS sent successfully to ${contact.name}',
                  );
                  break;
                case SendStatus.DELIVERED:
                  debugPrint('✅ Cancellation SMS delivered to ${contact.name}');
                  break;
              }
            },
          );

          // Small delay between messages
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          debugPrint(
            '❌ Failed to send cancellation SMS to ${contact.name}: $e',
          );
          // Continue sending to other contacts even if one fails
        }
      }

      debugPrint('📱 Emergency cancellation SMS sending completed');
    } catch (e) {
      debugPrint('❌ Emergency cancellation SMS sending failed: $e');
    }
  }

  /// Call the highest priority emergency contact
  Future<void> _callTopPriorityContact(List<EmergencyContact> contacts) async {
    // Validate that we have emergency contacts
    if (contacts.isEmpty) {
      debugPrint('❌ No emergency contacts available for calling');
      throw Exception(
        'No emergency contacts configured. Please add emergency contacts in settings.',
      );
    }

    try {
      // Get active contacts sorted by priority
      final activeContacts =
          contacts.where((contact) => contact.isActive).toList()
            ..sort((a, b) => a.priority.compareTo(b.priority));

      if (activeContacts.isEmpty) {
        debugPrint('❌ No active emergency contacts available for calling');
        throw Exception(
          'No active emergency contacts configured. Please activate emergency contacts in settings.',
        );
      }

      // Get the first (highest priority) emergency contact
      final topPriorityContact = activeContacts.first;

      // Validate the phone number format (basic validation)
      if (!_isValidPhoneNumber(topPriorityContact.phone)) {
        debugPrint(
          '❌ Invalid phone number format: ${topPriorityContact.phone}',
        );
        throw Exception(
          'Invalid emergency contact number. Please check your emergency contacts.',
        );
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
        if (_settings.dataBackupEnabled) {
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
        if (_settings.dataBackupEnabled) {
          await _logEmergencyCall(topPriorityContact, false);
        }

        throw Exception(
          'Unable to place emergency call to primary contact. SMS and other alerts are still being sent.',
        );
      }
    } catch (e) {
      debugPrint('🚨 Error during emergency call: $e');

      // Try secondary contact if available
      final activeContacts =
          contacts.where((contact) => contact.isActive).toList()
            ..sort((a, b) => a.priority.compareTo(b.priority));

      if (activeContacts.length > 1) {
        await _trySecondaryEmergencyCall(activeContacts);
      }

      // Don't let call failure stop other emergency notifications
      throw Exception(
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

        if (_settings.dataBackupEnabled) {
          await _logEmergencyCall(secondaryContact, true, isSecondary: true);
        }
      } else {
        debugPrint(
          '❌ Failed to call secondary contact: ${secondaryContact.name}',
        );

        if (_settings.dataBackupEnabled) {
          await _logEmergencyCall(secondaryContact, false, isSecondary: true);
        }
      }
    } catch (e) {
      debugPrint('🚨 Error calling secondary contact: $e');
    }
  }

  /// Log emergency call attempt
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

  /// Send push notifications to emergency contacts
  Future<void> _sendEmergencyPushNotifications() async {
    // TODO: Implement push notification sending
    // This would use Firebase Cloud Messaging or similar service
    debugPrint('Emergency push notifications would be sent');
  }

  /// Log emergency event for backup
  Future<void> _logEmergencyEvent(SafetyState state) async {
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

  /// Log emergency cancellation
  Future<void> _logEmergencyCancellation(DateTime? lastEmergencyTime) async {
    // TODO: Implement emergency cancellation logging
    final cancellationLog = {
      'timestamp': DateTime.now().toIso8601String(),
      'original_emergency_time': lastEmergencyTime?.toIso8601String(),
      'cancelled_by_user': true,
    };

    debugPrint('Emergency cancellation logged: $cancellationLog');
  }

  /// Trigger device vibration for emergency
  Future<void> _triggerEmergencyVibration() async {
    // TODO: Implement device vibration
    // This would use HapticFeedback or vibration plugin
    debugPrint('Emergency vibration triggered');
  }

  /// Play emergency sound
  Future<void> _playEmergencySound() async {
    // TODO: Implement emergency sound
    // This would use audioplayers or similar plugin
    debugPrint('Emergency sound would play');
  }

  /// Check if SMS permissions are granted
  Future<bool> requestSmsPermissions() async {
    try {
      bool permissionsGranted =
          await _telephony.requestPhoneAndSmsPermissions ?? false;

      debugPrint(
        permissionsGranted
            ? '✅ SMS permissions granted by user'
            : '❌ SMS permissions denied by user',
      );

      return permissionsGranted;
    } catch (e) {
      debugPrint('❌ Error requesting SMS permissions: $e');
      return false;
    }
  }

  /// Check if SMS permissions are currently granted
  Future<bool> hasSmsPermissions() async {
    try {
      // Check if we can send SMS (this is a simple way to check permissions)
      bool permissionsGranted =
          await _telephony.requestPhoneAndSmsPermissions ?? false;
      return permissionsGranted;
    } catch (e) {
      debugPrint('❌ Error checking SMS permissions: $e');
      return false;
    }
  }

  /// Check SMS permissions on initialization
  Future<SafetyState> checkSmsPermissions(SafetyState currentState) async {
    try {
      bool permissionsGranted =
          await _telephony.requestPhoneAndSmsPermissions ?? false;

      if (!permissionsGranted) {
        debugPrint(
          '⚠️ SMS permissions not granted. Emergency SMS may not work.',
        );
        return currentState.copyWith(
          error:
              'SMS permissions required for emergency alerts. Grant permissions in app settings.',
        );
      } else {
        debugPrint('✅ SMS permissions granted');
        return currentState;
      }
    } catch (e) {
      debugPrint('❌ Error checking SMS permissions: $e');
      return currentState;
    }
  }

  /// Send a test SMS to verify functionality
  Future<bool> sendTestSms(String phoneNumber) async {
    try {
      bool permissionsGranted =
          await _telephony.requestPhoneAndSmsPermissions ?? false;

      if (!permissionsGranted) {
        throw Exception('SMS permissions required to send test message.');
      }

      final testMessage = '''
📱 TEST MESSAGE from Nirbhay Safety App

This is a test message to verify that SMS functionality is working correctly.

Time: ${DateTime.now().toString()}

If you received this message, emergency SMS alerts are properly configured.

- Nirbhay Safety System
''';

      await _telephony.sendSms(
        to: phoneNumber,
        message: testMessage,
        isMultipart: true,
        statusListener: (SendStatus status) {
          switch (status) {
            case SendStatus.SENT:
              debugPrint('✅ Test SMS sent successfully');
              break;
            case SendStatus.DELIVERED:
              debugPrint('✅ Test SMS delivered successfully');
              break;
          }
        },
      );

      debugPrint('📱 Test SMS sent to: $phoneNumber');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to send test SMS: $e');
      rethrow;
    }
  }

  /// Validates if a phone number has a basic valid format
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
}
