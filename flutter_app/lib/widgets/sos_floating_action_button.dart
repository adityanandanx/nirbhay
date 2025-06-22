import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import 'sos_dialog.dart';

class SOSFloatingActionButton extends ConsumerWidget {
  const SOSFloatingActionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safetyState = ref.watch(safetyStateProvider);

    // Only show if safety mode is active
    if (!safetyState.isSafetyModeActive) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton.extended(
      onPressed: () => SOSDialog.show(context, ref),
      backgroundColor: Colors.red.shade600,
      foregroundColor: Colors.white,
      elevation: 8,
      label: const Text(
        'SOS',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
      icon: const Icon(Icons.emergency, size: 24),
    );
  }
}
