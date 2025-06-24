import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Settings State Model
class SettingsState {
  final bool emergencyAlertsEnabled;
  final bool locationSharingEnabled;
  final bool automaticDetectionEnabled;
  final bool voiceDetectionEnabled;
  final bool vibrationEnabled;
  final bool soundEnabled;
  final bool biometricEnabled;
  final bool dataBackupEnabled;
  final String alertSensitivity;
  final int sosCountdownTime;
  final bool isLoading;
  final String? error;

  const SettingsState({
    this.emergencyAlertsEnabled = true,
    this.locationSharingEnabled = true,
    this.automaticDetectionEnabled = true,
    this.voiceDetectionEnabled = true,
    this.vibrationEnabled = true,
    this.soundEnabled = true,
    this.biometricEnabled = false,
    this.dataBackupEnabled = true,
    this.alertSensitivity = 'Medium',
    this.sosCountdownTime = 30,
    this.isLoading = false,
    this.error,
  });

  SettingsState copyWith({
    bool? emergencyAlertsEnabled,
    bool? locationSharingEnabled,
    bool? automaticDetectionEnabled,
    bool? voiceDetectionEnabled,
    bool? vibrationEnabled,
    bool? soundEnabled,
    bool? biometricEnabled,
    bool? dataBackupEnabled,
    String? alertSensitivity,
    int? sosCountdownTime,
    bool? isLoading,
    String? error,
  }) {
    return SettingsState(
      emergencyAlertsEnabled:
          emergencyAlertsEnabled ?? this.emergencyAlertsEnabled,
      locationSharingEnabled:
          locationSharingEnabled ?? this.locationSharingEnabled,
      automaticDetectionEnabled:
          automaticDetectionEnabled ?? this.automaticDetectionEnabled,
      voiceDetectionEnabled:
          voiceDetectionEnabled ?? this.voiceDetectionEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      dataBackupEnabled: dataBackupEnabled ?? this.dataBackupEnabled,
      alertSensitivity: alertSensitivity ?? this.alertSensitivity,
      sosCountdownTime: sosCountdownTime ?? this.sosCountdownTime,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Settings State Notifier
class SettingsStateNotifier extends StateNotifier<SettingsState> {
  SettingsStateNotifier() : super(const SettingsState()) {
    _loadSettings();
  }

  static const String _keyEmergencyAlerts = 'emergency_alerts_enabled';
  static const String _keyLocationSharing = 'location_sharing_enabled';
  static const String _keyAutomaticDetection = 'automatic_detection_enabled';
  static const String _keyVoiceDetection = 'voice_detection_enabled';
  static const String _keyVibration = 'vibration_enabled';
  static const String _keySound = 'sound_enabled';
  static const String _keyBiometric = 'biometric_enabled';
  static const String _keyDataBackup = 'data_backup_enabled';
  static const String _keyAlertSensitivity = 'alert_sensitivity';
  static const String _keySosCountdownTime = 'sos_countdown_time';

  Future<void> _loadSettings() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();

      state = state.copyWith(
        emergencyAlertsEnabled: prefs.getBool(_keyEmergencyAlerts) ?? true,
        locationSharingEnabled: prefs.getBool(_keyLocationSharing) ?? true,
        automaticDetectionEnabled:
            prefs.getBool(_keyAutomaticDetection) ?? true,
        voiceDetectionEnabled: prefs.getBool(_keyVoiceDetection) ?? true,
        vibrationEnabled: prefs.getBool(_keyVibration) ?? true,
        soundEnabled: prefs.getBool(_keySound) ?? true,
        biometricEnabled: prefs.getBool(_keyBiometric) ?? false,
        dataBackupEnabled: prefs.getBool(_keyDataBackup) ?? true,
        alertSensitivity: prefs.getString(_keyAlertSensitivity) ?? 'Medium',
        sosCountdownTime: prefs.getInt(_keySosCountdownTime) ?? 30,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setBool(_keyEmergencyAlerts, state.emergencyAlertsEnabled),
        prefs.setBool(_keyLocationSharing, state.locationSharingEnabled),
        prefs.setBool(_keyAutomaticDetection, state.automaticDetectionEnabled),
        prefs.setBool(_keyVoiceDetection, state.voiceDetectionEnabled),
        prefs.setBool(_keyVibration, state.vibrationEnabled),
        prefs.setBool(_keySound, state.soundEnabled),
        prefs.setBool(_keyBiometric, state.biometricEnabled),
        prefs.setBool(_keyDataBackup, state.dataBackupEnabled),
        prefs.setString(_keyAlertSensitivity, state.alertSensitivity),
        prefs.setInt(_keySosCountdownTime, state.sosCountdownTime),
      ]);
    } catch (e) {
      state = state.copyWith(error: 'Failed to save settings: ${e.toString()}');
    }
  }

  void setEmergencyAlertsEnabled(bool enabled) {
    state = state.copyWith(emergencyAlertsEnabled: enabled);
    _saveSettings();
  }

  void setLocationSharingEnabled(bool enabled) {
    state = state.copyWith(locationSharingEnabled: enabled);
    _saveSettings();
  }

  void setAutomaticDetectionEnabled(bool enabled) {
    state = state.copyWith(automaticDetectionEnabled: enabled);
    _saveSettings();
  }

  void setVoiceDetectionEnabled(bool enabled) {
    state = state.copyWith(voiceDetectionEnabled: enabled);
    _saveSettings();
  }

  void setVibrationEnabled(bool enabled) {
    state = state.copyWith(vibrationEnabled: enabled);
    _saveSettings();
  }

  void setSoundEnabled(bool enabled) {
    state = state.copyWith(soundEnabled: enabled);
    _saveSettings();
  }

  void setBiometricEnabled(bool enabled) {
    state = state.copyWith(biometricEnabled: enabled);
    _saveSettings();
  }

  void setDataBackupEnabled(bool enabled) {
    state = state.copyWith(dataBackupEnabled: enabled);
    _saveSettings();
  }

  void setAlertSensitivity(String sensitivity) {
    state = state.copyWith(alertSensitivity: sensitivity);
    _saveSettings();
  }

  void setSosCountdownTime(int countdownTime) {
    state = state.copyWith(sosCountdownTime: countdownTime);
    _saveSettings();
  }

  void resetToDefaults() {
    state = const SettingsState();
    _saveSettings();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}
