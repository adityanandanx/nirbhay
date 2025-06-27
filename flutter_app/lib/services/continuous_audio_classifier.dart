import 'dart:async';

import 'package:flutter/foundation.dart';

import 'audio_capture_service.dart';
import 'yamnet_classifier_service.dart';

/// Service for continuous audio classification using YAMNet
class ContinuousAudioClassifier {
  final void Function(String label, double confidence) onSoundDetected;

  late final YamnetClassifierService _classifier;
  late final AudioCaptureService _audioCapture;
  bool _isInitialized = false;

  ContinuousAudioClassifier({required this.onSoundDetected});

  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('🎯 Initializing ContinuousAudioClassifier...');
    try {
      // Initialize the YAMNet classifier
      _classifier = YamnetClassifierService();
      await _classifier.initialize();
      debugPrint('✅ YAMNet classifier initialized');

      // Initialize audio capture with YAMNet requirements
      _audioCapture = AudioCaptureService(
        onAudioBuffer: _processAudioBuffer,
        sampleRate: _classifier.sampleRate,
        requiredSamples: _classifier.requiredSamples,
      );
      await _audioCapture.initialize();
      debugPrint('✅ Audio capture initialized');

      _isInitialized = true;
      debugPrint('✅ ContinuousAudioClassifier ready');
    } catch (e) {
      debugPrint('❌ Failed to initialize ContinuousAudioClassifier: $e');
      rethrow;
    }
  }

  Future<void> _processAudioBuffer(Float32List samples) async {
    try {
      final result = await _classifier.classifyWaveform(samples);
      if (result != null) {
        final (label, confidence) = result;
        onSoundDetected(label, confidence);
      }
    } catch (e) {
      debugPrint('❌ Error classifying audio: $e');
    }
  }

  Future<void> startClassification() async {
    if (!_isInitialized) {
      throw StateError('ContinuousAudioClassifier not initialized');
    }

    debugPrint('🎧 Starting continuous audio classification...');
    try {
      await _audioCapture.startRecording();
      debugPrint('✅ Classification started');
    } catch (e) {
      debugPrint('❌ Failed to start classification: $e');
      rethrow;
    }
  }

  Future<void> stopClassification() async {
    if (!_isInitialized) return;

    debugPrint('🛑 Stopping audio classification...');
    try {
      await _audioCapture.stopRecording();
      debugPrint('✅ Classification stopped');
    } catch (e) {
      debugPrint('❌ Error stopping classification: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {
    debugPrint('🧹 Cleaning up ContinuousAudioClassifier...');
    try {
      await stopClassification();
      await _audioCapture.dispose();
      _classifier.dispose();
      _isInitialized = false;
      debugPrint('✅ ContinuousAudioClassifier cleanup complete');
    } catch (e) {
      debugPrint('❌ Error during cleanup: $e');
      rethrow;
    }
  }

  // Service state
  bool get isClassifying => _isInitialized && _audioCapture.isRecording;
  bool get isInitialized => _isInitialized;
  List<String> get supportedSoundLabels =>
      _isInitialized ? _classifier.labels : [];
}
