import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
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
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isPaused = false;
  Timer? _cooldownTimer;
  Timer? _speechTimer;
  Function(String)? _onSpeechRecognized;

  // Different thresholds and cooldowns for different types of sounds
  static final _soundCategories = {
    // Speech-related sounds
    'speech': SoundCategory(
      sounds: {
        'Speech',
        'Conversation',
        'Male speech, man speaking',
        'Female speech, woman speaking',
        'Child speech, kid speaking',
      },
      threshold: 0.4,
      cooldown: const Duration(seconds: 15),
    ),
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

  // Keywords that indicate distress in speech
  static final Set<String> _distressKeywords = {
    'help',
    'emergency',
    'sos',
    'danger',
    'fire',
    'hurt',
    'injured',
    'attack',
    'police',
    'ambulance',
    'save',
    'scared',
    'threat',
    'please help',
    'call police',
    'call ambulance',
    'medical',
    'bleeding',
    'unconscious',
    'chest pain',
    'trouble breathing',
    'heart attack',
    'stroke',
  };

  /// Initialize the service
  Future<void> initialize({
    required Function() onDistressDetected,
    Function(String speech)? onSpeechRecognized,
    Function(String error)? onError,
    Function(String label, double confidence)? onSoundDetected,
  }) async {
    if (_isInitialized) return;

    try {
      _onSpeechRecognized = onSpeechRecognized;
      _classifier = ContinuousAudioClassifier(
        onSoundDetected: (label, confidence) {
          // Forward the detected sound to the callback
          onSoundDetected?.call(label, confidence);
          // Process the sound for distress detection
          _processDetectedSound(label, confidence, onDistressDetected);
        },
      );
      await _classifier.initialize();

      bool available = await _speech.initialize(
        onError: (error) {
          debugPrint('🎤 Speech recognition error: ${error.errorMsg}');
          onError?.call(error.errorMsg);
        },
        onStatus: (status) {
          debugPrint('🎤 Speech recognition status: $status');
          if (status == 'done' && _speechTimer != null) {
            _speechTimer?.cancel();
            _speechTimer = null;
          }
        },
      );

      if (!available) {
        debugPrint('🎤 The user has denied the use of speech recognition.');
        onError?.call('Speech recognition permission denied');
        return;
      }

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

  /// Start speech recognition for a short duration
  Future<void> _startSpeechRecognition(
    Function(String)? onSpeechRecognized, [
    Function()? onDistressDetected,
  ]) async {
    if (!_speech.isAvailable) {
      debugPrint('🎤 Speech recognition not available');
      return;
    }

    if (_speech.isListening) {
      debugPrint('🎤 Speech recognition already active');
      return;
    }

    try {
      // Stop classification completely before starting speech recognition
      debugPrint('📝 Stopping classification for speech recognition...');
      await _pauseDistressDetection();

      debugPrint('🎤 Starting speech recognition...');
      await _speech.listen(
        onResult: (result) {
          debugPrint(
            '🎤 Speech result: ${result.recognizedWords} (${result.finalResult ? 'final' : 'partial'})',
          );
          if (result.finalResult) {
            final speech = result.recognizedWords;
            onSpeechRecognized?.call(speech);

            // Check for distress keywords and trigger SOS if found
            if (_containsDistressKeywords(speech)) {
              debugPrint('🚨 Distress keywords detected in speech: $speech');
              onDistressDetected?.call();
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
          onDevice: true, // Prefer on-device recognition if available
        ),
      );

      // Stop speech recognition after 10 seconds
      _speechTimer?.cancel();
      _speechTimer = Timer(const Duration(seconds: 10), () async {
        debugPrint('🎤 Stopping speech recognition (timeout)');
        if (_speech.isListening) {
          await _speech.stop();
        }
        _speechTimer = null;
        await _resumeDistressDetection();
      });
    } catch (e) {
      debugPrint('Error starting speech recognition: $e');
      if (_speech.isListening) {
        await _speech.stop();
      }
      _speechTimer?.cancel();
      _speechTimer = null;
      await _resumeDistressDetection();
    }
  }

  /// Check if the recognized speech contains any distress keywords
  bool _containsDistressKeywords(String speech) {
    final words = speech.toLowerCase().split(' ');

    // Check for single word matches
    if (words.any((word) => _distressKeywords.contains(word))) {
      return true;
    }

    // Check for phrase matches
    return _distressKeywords.any(
      (keyword) => speech.toLowerCase().contains(keyword.toLowerCase()),
    );
  }

  /// Process a detected sound and trigger alerts based on priority
  void _processDetectedSound(
    String label,
    double confidence,
    Function() onDistressDetected,
  ) {
    // Don't process if we're already doing speech recognition
    if (_speech.isListening || _isPaused) {
      return;
    }

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

    // Process speech recognition for speech sounds
    if (priority == 'speech' &&
        category != null &&
        confidence >= category.threshold &&
        _cooldownTimer == null) {
      debugPrint(
        '🎤 Speech sound detected: $label (${(confidence * 100).toStringAsFixed(1)}%)',
      );
      _startSpeechRecognition((speech) {
        if (_onSpeechRecognized != null) {
          _onSpeechRecognized!(speech);
        }
      }, onDistressDetected);

      // Start cooldown timer
      _cooldownTimer = Timer(category.cooldown, () {
        _cooldownTimer = null;
      });
      return;
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

  /// Pause monitoring for distress sounds
  Future<void> pause() async {
    if (_isPaused) return;

    _isPaused = true;
    await _classifier.stopClassification();
    debugPrint('⏸️ Distress detection paused');
  }

  /// Resume monitoring for distress sounds
  Future<void> resume() async {
    if (!_isPaused) return;

    _isPaused = false;
    await _classifier.startClassification();
    debugPrint('▶️ Distress detection resumed');
  }

  /// Internal function to pause distress detection for speech recognition
  Future<void> _pauseDistressDetection() async {
    if (!_isPaused && _isListening) {
      _isPaused = true;
      await _classifier.stopClassification();
      debugPrint('📝 Paused distress detection for speech recognition');
    }
  }

  /// Internal function to resume distress detection after speech recognition
  Future<void> _resumeDistressDetection() async {
    if (_isPaused && _isListening) {
      await Future.delayed(const Duration(milliseconds: 200));
      await _classifier.startClassification();
      _isPaused = false;
      debugPrint('📝 Resumed distress detection after speech recognition');
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
        if (_speech.isListening) {
          await _speech.stop();
        }
        _isInitialized = false;
      }
      _cooldownTimer?.cancel();
      _speechTimer?.cancel();
    } catch (e) {
      debugPrint('Error disposing distress detection service: $e');
      rethrow;
    }
  }
}
