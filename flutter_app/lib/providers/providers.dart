import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/safety_state.dart';
import 'safety_provider.dart';
import 'ble_provider.dart';
import 'settings_provider.dart';

/**
 * Provider Setup Guide
 * 
 * This file defines the safety provider which depends on BLE and Settings providers.
 * 
 * To properly set up the providers, make sure that:
 * 1. The BLE provider is exposed in ble_provider.dart with an accessible notifier
 * 2. The Settings provider is exposed in settings_provider.dart with an accessible notifier
 * 3. The actual provider names should match what's expected in the SafetyStateNotifier
 *
 * Example usage in your app:
 * ```dart
 * final safetyState = ref.watch(safetyProvider);
 * final safetyNotifier = ref.watch(safetyProvider.notifier);
 * ```
 */

/// Safety Provider - Replace the ref.read lines with your actual provider references
final safetyProvider = StateNotifierProvider<SafetyStateNotifier, SafetyState>((
  ref,
) {
  // TODO: Replace these with your actual provider references
  // Example:
  // final bleNotifier = ref.read(bleStateProvider.notifier);
  // final settingsNotifier = ref.read(settingsProvider.notifier);

  // For now, creating mock instances for compilation - replace these!
  final bleNotifier =
      throw UnimplementedError('Replace with actual BLE provider reference');
  final settingsNotifier =
      throw UnimplementedError(
        'Replace with actual Settings provider reference',
      );

  return SafetyStateNotifier(bleNotifier, settingsNotifier);
});
