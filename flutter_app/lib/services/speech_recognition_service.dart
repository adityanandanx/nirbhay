import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Service for voice-activated emergency detection
/// Continuously listens for emergency keywords and triggers alerts
class SpeechRecognitionService {
  final SpeechToText _speechToText = SpeechToText();

  // State tracking
  bool _isInitialized = false;
  bool _isListening = false;
  bool _shouldContinueListening = false;

  // Emergency cooldown tracking
  DateTime? _lastEmergencyTime;
  static const _emergencyCooldownPeriod = Duration(minutes: 2);
  bool _isProcessingEmergency = false;

  // Track last detected keywords to avoid duplicates
  String? _lastDetectedKeyword;
  DateTime? _lastKeywordTime;
  static const _keywordDuplicateThreshold = Duration(seconds: 10);

  // Speech recognition settings
  final int _listeningTimeout = 30; // seconds per listening session
  final String _localeId = 'en_US'; // default locale

  // Keywords that trigger emergency alert
  final Set<String> _emergencyKeywords = {
    'help',
    'emergency',
    'danger',
    'save me',
    'sos',
    'bachao', // Hindi for "save me"
    'madad', // Hindi for "help"
    'aah',
    'stop',
    'no',
    'don\'t',
    'scream',
    'fire',
    'attack',
  };

  // Callback for when emergency is detected
  Function()? onEmergencyDetected;

  // Debug callback for logging detected words
  Function(String)? onSpeechResult;

  // Flag to prevent multiple simultaneous initialization attempts
  bool _isInitializing = false;

  /// Initialize the speech recognition service
  Future<bool> initialize() async {
    // Return early if already initialized
    if (_isInitialized) return true;

    // Return early if already initializing
    if (_isInitializing) {
      // Wait a bit and check if initialization completed
      await Future.delayed(const Duration(milliseconds: 500));
      return _isInitialized;
    }

    _isInitializing = true;

    try {
      // Ensure we're stopped before initializing
      try {
        await _speechToText.stop();
      } catch (e) {
        // Ignore errors from stop() as we're reinitializing anyway
      }

      // Wait a moment to ensure resources are released
      await Future.delayed(const Duration(milliseconds: 500));

      // Initialize with a timeout to prevent hanging
      bool? result;
      try {
        result = await _speechToText
            .initialize(
              onError: _errorListener,
              onStatus: _statusListener,
              debugLogging: true,
            )
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                debugPrint('⚠️ Speech recognition initialization timed out');
                return false;
              },
            );
      } catch (e) {
        debugPrint('❌ Exception during initialize(): $e');
        result = false;
      }

      // Handle result (should not be null with our try/catch, but be safe)
      _isInitialized = result == true;

      debugPrint(
        _isInitialized
            ? '✅ Speech recognition initialized successfully'
            : '❌ Failed to initialize speech recognition',
      );

      return _isInitialized;
    } catch (e) {
      debugPrint('❌ Error initializing speech recognition: $e');
      _isInitialized = false;
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Start continuous listening for emergency keywords
  Future<bool> startListening() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    // Set flag to continue listening after each session ends
    _shouldContinueListening = true;

    return _startListeningSession();
  }

  // Flag to prevent multiple simultaneous start attempts
  bool _isStarting = false;

  /// Internal method to start a single listening session
  Future<bool> _startListeningSession() async {
    // Prevent multiple simultaneous start attempts
    if (_isListening || _isStarting) return true;

    _isStarting = true;

    try {
      debugPrint('🎤 Starting speech recognition session');

      // Ensure previous session is completely stopped
      try {
        await _speechToText.stop();
      } catch (e) {
        debugPrint('⚠️ Error stopping previous session: $e');
        // Continue anyway
      }

      // Longer delay to ensure resources are released
      await Future.delayed(const Duration(milliseconds: 500));

      bool? success;
      try {
        success = await _speechToText.listen(
          onResult: _onSpeechResult,
          listenFor: Duration(seconds: _listeningTimeout),
          pauseFor: const Duration(seconds: 3),
          localeId: _localeId,
          cancelOnError: false,
          partialResults: true,
          listenMode: ListenMode.confirmation,
        );
      } catch (e) {
        debugPrint('❌ Exception during listen() call: $e');
        success = false;
      }

      // Handle result (should not be null with our try/catch, but be safe)
      _isListening = success == true;

      debugPrint(
        _isListening
            ? '✅ Speech recognition session started'
            : '❌ Failed to start speech recognition',
      );

      return _isListening;
    } catch (e) {
      debugPrint('❌ Error starting speech recognition: $e');
      _isListening = false;
      return false;
    } finally {
      _isStarting = false;
    }
  }

  /// Stop listening for emergency keywords
  Future<void> stopListening() async {
    _shouldContinueListening = false;
    _isListening = false;
    _isStarting = false;

    try {
      await _speechToText.stop();
      debugPrint('🛑 Speech recognition stopped');
    } catch (e) {
      debugPrint('❌ Error stopping speech recognition: $e');
      // Even if there's an error stopping, reset our state
      _isInitialized = false;

      // Re-initialize the speech to text engine to clear any stuck states
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        await initialize();
      } catch (e) {
        debugPrint('⚠️ Failed to re-initialize speech recognition: $e');
      }
    }
  }

  /// Check if the recognized speech contains any emergency keywords
  bool _containsEmergencyKeyword(String speech) {
    final lowercaseSpeech = speech.toLowerCase();

    for (final keyword in _emergencyKeywords) {
      if (lowercaseSpeech.contains(keyword.toLowerCase())) {
        debugPrint('🚨 Emergency keyword detected: $keyword');
        return true;
      }
    }

    return false;
  }

  /// Handle speech recognition results
  void _onSpeechResult(SpeechRecognitionResult result) {
    final recognizedWords = result.recognizedWords;

    // Notify listener of speech result (for debugging)
    onSpeechResult?.call(recognizedWords);

    // Only process final results to avoid multiple triggers
    if (!result.finalResult) {
      return; // Skip interim results
    }

    // Check for emergency keywords
    if (recognizedWords.isNotEmpty &&
        !_isProcessingEmergency && // Prevent concurrent processing
        _containsEmergencyKeyword(recognizedWords)) {
      // Check if we're still within the cooldown period
      final now = DateTime.now();
      if (_lastEmergencyTime == null ||
          now.difference(_lastEmergencyTime!) > _emergencyCooldownPeriod) {
        // Prevent concurrent emergency processing
        _isProcessingEmergency = true;

        debugPrint('⚠️ EMERGENCY DETECTED - Triggering alert');

        // Update tracking info
        _lastEmergencyTime = now;

        // Track the keyword to prevent duplicates
        _lastDetectedKeyword = recognizedWords.toLowerCase();
        _lastKeywordTime = now;

        // Trigger emergency callback (in a try-catch to ensure we release lock)
        try {
          onEmergencyDetected?.call();
        } catch (e) {
          debugPrint('❌ Error in emergency callback: $e');
        } finally {
          // Release processing lock after a delay to prevent rapid re-triggering
          Future.delayed(const Duration(seconds: 5), () {
            _isProcessingEmergency = false;
          });
        }

        // Stop listening after emergency is detected
        stopListening();
      } else {
        debugPrint('🚫 Emergency cooldown active, ignoring detection');
      }
    } else if (recognizedWords.isNotEmpty &&
        _lastDetectedKeyword != null &&
        _lastKeywordTime != null) {
      // Check if this is too similar to a recent detection (avoid duplicates)
      final now = DateTime.now();
      if (now.difference(_lastKeywordTime!) < _keywordDuplicateThreshold &&
          _isSimilarText(
            recognizedWords.toLowerCase(),
            _lastDetectedKeyword!,
          )) {
        debugPrint('🔄 Ignoring duplicate speech input');
        return;
      }
    }

    // Track last detected keyword and time to avoid duplicates
    if (recognizedWords.isNotEmpty) {
      _lastDetectedKeyword = recognizedWords;
      _lastKeywordTime = DateTime.now();
    }
  }

  /// Handle speech recognition errors
  void _errorListener(SpeechRecognitionError error) {
    debugPrint('🔊 Speech recognition error: ${error.errorMsg}');

    // Reset state flags
    _isListening = false;

    // These errors indicate we need to reinitialize
    if (error.permanent ||
        error.errorMsg == 'error_busy' ||
        error.errorMsg == 'error_no_match') {
      _isInitialized = false;

      // Reinitialize after errors that suggest the engine is in a bad state
      Future.delayed(const Duration(seconds: 2), () async {
        if (_shouldContinueListening) {
          try {
            await _speechToText.stop();
            await Future.delayed(const Duration(seconds: 1));
            await initialize();
          } catch (e) {
            debugPrint('⚠️ Error during reinitialize: $e');
          }
        }
      });
    }

    // If we should continue listening but not currently in a retry cycle,
    // restart the listening session after a longer delay
    if (_shouldContinueListening && !_isListening && !_isStarting) {
      Future.delayed(const Duration(seconds: 3), () {
        if (_shouldContinueListening && !_isListening && !_isStarting) {
          _startListeningSession();
        }
      });
    }
  }

  /// Handle speech recognition status updates
  void _statusListener(String status) async {
    debugPrint('🔊 Speech recognition status: $status');

    // Handle various status updates
    switch (status) {
      case 'done':
        _isListening = false;

        // Only attempt to restart if we should continue listening
        if (_shouldContinueListening && !_isStarting) {
          // Add a longer delay before starting the next session to avoid conflicts
          await Future.delayed(const Duration(seconds: 1));

          if (_shouldContinueListening && !_isListening && !_isStarting) {
            await _startListeningSession();
          }
        }
        break;

      case 'notListening':
        _isListening = false;
        break;

      case 'listening':
        _isListening = true;
        break;
    }
  }

  /// Add custom emergency keywords
  void addEmergencyKeywords(List<String> keywords) {
    _emergencyKeywords.addAll(keywords);
  }

  /// Change the locale for speech recognition
  Future<void> setLocale(String localeId) async {
    // Check if locale is supported
    final locales = await _speechToText.locales();
    final isSupported = locales.any((locale) => locale.localeId == localeId);

    if (isSupported) {
      // Need to restart listening with new locale
      final wasListening = _isListening;

      if (wasListening) {
        await stopListening();
      }

      // Set new locale
      // We create a new instance to avoid issues with some implementations
      await _speechToText.stop();
      _isInitialized = false;
      await initialize();

      if (wasListening) {
        await startListening();
      }
    } else {
      debugPrint('❌ Locale not supported: $localeId');
    }
  }

  /// Get all available locales for speech recognition
  Future<List<String>> getAvailableLocales() async {
    final locales = await _speechToText.locales();
    return locales
        .map((locale) => '${locale.localeId} (${locale.name})')
        .toList();
  }

  /// Check if speech recognition is available on this device
  Future<bool> isAvailable() async {
    if (!_isInitialized) {
      return await initialize();
    }
    return _isInitialized;
  }

  /// Check if two text strings are similar (to avoid duplicate triggers)
  bool _isSimilarText(String text1, String text2) {
    // If either string contains the other, they're similar enough
    if (text1.contains(text2) || text2.contains(text1)) {
      return true;
    }

    // Count shared words to determine similarity
    final words1 = text1.split(' ');
    final words2 = text2.split(' ');

    // Count matching words
    int matchingWords = 0;
    for (final word in words1) {
      if (word.length > 3 && words2.contains(word)) {
        matchingWords++;
      }
    }

    // If more than half the words match, consider it similar
    return matchingWords >= (words1.length / 2).ceil();
  }
}
