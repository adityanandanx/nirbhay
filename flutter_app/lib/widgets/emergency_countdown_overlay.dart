import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';

class EmergencyCountdownOverlay extends ConsumerWidget {
  const EmergencyCountdownOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safetyState = ref.watch(safetyStateProvider);

    // Calculate remaining seconds
    int remainingSeconds = 0;
    if (safetyState.isEmergencyCountdownActive &&
        safetyState.emergencyCountdownStartTime != null) {
      final elapsedDuration = DateTime.now().difference(
        safetyState.emergencyCountdownStartTime!,
      );
      final totalSeconds = ref.read(settingsStateProvider).sosCountdownTime;
      remainingSeconds = totalSeconds - elapsedDuration.inSeconds;
      if (remainingSeconds < 0) remainingSeconds = 0;
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withOpacity(0.7),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'EMERGENCY ALERT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Triggering in $remainingSeconds seconds',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  ref
                      .read(safetyStateProvider.notifier)
                      .cancelEmergencyCountdown();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
