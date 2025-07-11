import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nirbhay_flutter/models/safety_state.dart';
import '../services/ble_service.dart';
import '../services/firebase_location_service.dart';
import 'auth_provider.dart';
import 'ble_provider.dart';
import 'settings_provider.dart';
import 'safety_provider.dart';
import 'location_tracking_provider.dart';

// Core service providers
final bleServiceProvider = Provider<BLEService>((ref) => BLEService());
final firebaseLocationServiceProvider = Provider<FirebaseLocationService>(
  (ref) => FirebaseLocationService(),
);

// Main app providers
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>(
  (ref) => AuthStateNotifier(),
);

final bleStateProvider = StateNotifierProvider<BLEStateNotifier, BLEState>(
  (ref) => BLEStateNotifier(ref.read(bleServiceProvider)),
);

final settingsStateProvider =
    StateNotifierProvider<SettingsStateNotifier, SettingsState>(
      (ref) => SettingsStateNotifier(),
    );

final safetyStateProvider =
    StateNotifierProvider<SafetyStateNotifier, SafetyState>(
      (ref) => SafetyStateNotifier(
        ref.read(bleStateProvider.notifier),
        ref.read(settingsStateProvider.notifier),
      ),
    );

final locationTrackingProvider = StateNotifierProvider<
  LocationTrackingNotifier,
  LocationTrackingState
>((ref) => LocationTrackingNotifier(ref.read(firebaseLocationServiceProvider)));
