import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/safety_flag_service.dart';
import '../models/safety_flag.dart';

// Provider for the SafetyFlagService
final safetyFlagServiceProvider = Provider<SafetyFlagService>((ref) {
  final service = SafetyFlagService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

// Provider for streaming safety flags
final safetyFlagsProvider = StreamProvider<List<SafetyFlag>>((ref) {
  final service = ref.watch(safetyFlagServiceProvider);
  return service.listenToSafetyFlags();
});

// Provider for managing safety flag state and actions
class SafetyFlagsNotifier extends StateNotifier<AsyncValue<void>> {
  final SafetyFlagService _service;

  SafetyFlagsNotifier(this._service) : super(const AsyncValue.data(null));

  Future<void> addSafetyFlag(
    LatLng location,
    String userId, {
    String? description,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _service.addSafetyFlag(location, userId, description: description);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> removeSafetyFlag(String flagId) async {
    state = const AsyncValue.loading();
    try {
      await _service.removeSafetyFlag(flagId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// Provider for safety flag actions
final safetyFlagsNotifierProvider =
    StateNotifierProvider<SafetyFlagsNotifier, AsyncValue<void>>((ref) {
      final service = ref.watch(safetyFlagServiceProvider);
      return SafetyFlagsNotifier(service);
    });
