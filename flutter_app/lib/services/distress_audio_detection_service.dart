import 'dart:async';
import 'package:flutter/foundation.dart';
import 'continuous_audio_classifier.dart';

class SoundCategory {
  final Set<String> sounds;
  final double threshold;
  final Duration cooldown;

  const SoundCategory({
    required this.sounds,
    required this.threshold,
    required this.cooldown,
  });
}

class DistressAudioDetectionService {
  late final ContinuousAudioClassifier _classifier;
  bool _isInitialized = false;
  bool _isListening = false;
  Timer? _cooldownTimer;

  // Different thresholds and cooldowns for different types of sounds
  static final _soundCategories = {
    // High-priority sounds (immediate response needed)
    'high_priority': SoundCategory(
      sounds: {
        'Screaming',
        'Baby cry, infant cry',
        'Children shouting',
        'Smoke detector, smoke alarm',
        'Fire alarm',
      },
      threshold: 0.2, // Lower threshold for critical sounds
      cooldown: const Duration(
        seconds: 15,
      ), // Shorter cooldown for critical sounds
    ),
    // Medium-priority sounds (potential emergency)
    'medium_priority': SoundCategory(
      sounds: {
        'Shout',
        'Bellow',
        'Yell',
        'Whoop',
        'Crying, sobbing',
        'Wail, moan',
        'Police car (siren)',
        'Ambulance (siren)',
        'Fire engine, fire truck (siren)',
        'Civil defense siren',
        'Emergency vehicle',
        'Siren',
      },
      threshold: 0.25,
      cooldown: const Duration(seconds: 30),
    ),
    // Low-priority sounds (need confirmation or context)
    'low_priority': SoundCategory(
      sounds: {'Whimper', 'Vehicle horn, car horn, honking', 'Car alarm'},
      threshold: 0.5, // Higher threshold to prevent false positives
      cooldown: const Duration(
        seconds: 45,
      ), // Longer cooldown for less critical sounds
    ),
  };

  /// Initialize the service
  Future<void> initialize({
    required Function() onDistressDetected,
    Function(String error)? onError,
  }) async {
    if (_isInitialized) return;

    try {
      _classifier = ContinuousAudioClassifier(
        onSoundDetected: (label, confidence) {
          _processDetectedSound(label, confidence, onDistressDetected);
        },
      );
      await _classifier.initialize();
      _isInitialized = true;
    } catch (e) {
      onError?.call(e.toString());
      debugPrint('Error initializing distress detection: $e');
      rethrow;
    }
  }

  /// Start monitoring for distress sounds
  Future<void> startListening() async {
    if (_isListening || !_isInitialized) return;

    try {
      await _classifier.startClassification();
      _isListening = true;
    } catch (e) {
      debugPrint('Error starting distress detection: $e');
      rethrow;
    }
  }

  /// Process a detected sound and trigger alerts based on priority
  void _processDetectedSound(
    String label,
    double confidence,
    Function() onDistressDetected,
  ) {
    // Find the priority category for this sound
    String? priority;
    SoundCategory? category;

    for (var entry in _soundCategories.entries) {
      if (entry.value.sounds.contains(label)) {
        priority = entry.key;
        category = entry.value;
        break;
      }
    }

    // Only process if it's a known distress sound and we're not in cooldown
    if (category != null &&
        confidence >= category.threshold &&
        _cooldownTimer == null) {
      debugPrint(
        '🚨 Distress sound detected: $label (${(confidence * 100).toStringAsFixed(1)}%) - Priority: $priority',
      );

      // Trigger the distress callback
      onDistressDetected();

      // Start cooldown timer to prevent rapid repeated triggers
      _cooldownTimer = Timer(category.cooldown, () {
        _cooldownTimer = null;
      });
    }
  }

  /// Stop monitoring for distress sounds
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _classifier.stopClassification();
      _isListening = false;
      _cooldownTimer?.cancel();
      _cooldownTimer = null;
    } catch (e) {
      debugPrint('Error stopping distress detection: $e');
      rethrow;
    }
  }

  /// Check if the service is currently monitoring for distress sounds
  bool get isListening => _isListening;

  /// Check if the service is properly initialized
  bool get isInitialized => _isInitialized;

  /// Dispose of resources
  Future<void> dispose() async {
    try {
      await stopListening();
      if (_isInitialized) {
        await _classifier.dispose();
        _isInitialized = false;
      }
      _cooldownTimer?.cancel();
    } catch (e) {
      debugPrint('Error disposing distress detection service: $e');
      rethrow;
    }
  }
}
