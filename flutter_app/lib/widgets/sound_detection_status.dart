import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';

class SoundDetectionStatus extends ConsumerWidget {
  const SoundDetectionStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the current detected sound and confidence from the state
    final safetyState = ref.watch(safetyStateProvider);
    final soundInfo = safetyState.detectedSound;

    if (!safetyState.isVoiceDetectionActive) {
      return const SizedBox.shrink(); // Don't show anything if detection is not active
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hearing, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Sound Detection',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (soundInfo != null) ...[
              Text(
                'Detected: ${soundInfo.$1}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: soundInfo.$2,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.blue.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Confidence: ${(soundInfo.$2 * 100).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ] else
              Text(
                'Monitoring for sounds...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
