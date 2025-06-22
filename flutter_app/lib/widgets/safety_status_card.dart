import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';

class SafetyStatusCard extends ConsumerWidget {
  const SafetyStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safetyState = ref.watch(safetyStateProvider);
    final bleState = ref.watch(bleStateProvider);
    final canActivate = bleState.isConnected;

    // Show error message if there's an error
    if (safetyState.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(safetyState.error!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        // Clear the error after showing it
        ref.read(safetyStateProvider.notifier).clearError();
      });
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              safetyState.isSafetyModeActive
                  ? [Colors.green.shade400, Colors.green.shade600]
                  : [Colors.purple.shade400, Colors.purple.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
                (safetyState.isSafetyModeActive ? Colors.green : Colors.purple)
                    .shade200,
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            safetyState.isSafetyModeActive ? Icons.shield : Icons.security,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            safetyState.isSafetyModeActive
                ? 'SAFETY MODE ACTIVE'
                : 'SAFETY MODE INACTIVE',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            safetyState.isSafetyModeActive
                ? 'You are protected and monitored'
                : canActivate
                ? 'Tap to activate protection'
                : 'Connect wearable device to activate',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed:
                safetyState.isLoading
                    ? null
                    : (safetyState.isSafetyModeActive || canActivate)
                    ? () =>
                        ref
                            .read(safetyStateProvider.notifier)
                            .toggleSafetyMode()
                    : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor:
                  safetyState.isSafetyModeActive ? Colors.green : Colors.purple,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child:
                safetyState.isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : Text(
                      safetyState.isSafetyModeActive
                          ? 'Deactivate'
                          : canActivate
                          ? 'Activate'
                          : 'Device Required',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
