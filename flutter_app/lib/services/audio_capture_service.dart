import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for continuous audio recording and processing using the record package
class AudioCaptureService {
  final _audioRecorder = AudioRecorder();
  final void Function(Float32List samples) onAudioBuffer;
  final int sampleRate;
  final int requiredSamples;

  StreamSubscription<List<int>>? _audioStreamSubscription;
  List<double> _audioBuffer = [];
  bool _isRecording = false;
  bool _isInitialized = false;

  AudioCaptureService({
    required this.onAudioBuffer,
    required this.sampleRate,
    required this.requiredSamples,
  });

  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('🎤 Initializing AudioCaptureService...');
    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw Exception('Microphone permission not granted');
      }

      // Check if recording is possible
      if (!await _audioRecorder.hasPermission()) {
        throw Exception('Recording permission not granted');
      }

      _isInitialized = true;
      debugPrint('✅ AudioCaptureService initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize AudioCaptureService: $e');
      rethrow;
    }
  }

  Future<void> startRecording() async {
    if (!_isInitialized) {
      throw StateError('AudioCaptureService not initialized');
    }

    if (_isRecording) {
      debugPrint('⚠️ Recording already in progress');
      return;
    }

    debugPrint('🎙️ Starting audio recording...');
    try {
      _audioBuffer.clear();
      _isRecording = true;

      // Start stream recording with PCM configuration
      final stream = await _audioRecorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          numChannels: 1,
          sampleRate: sampleRate,
        ),
      );
      debugPrint('✅ Recording started');

      // Listen to audio stream
      _audioStreamSubscription = stream.listen(
        (data) {
          if (!_isRecording) return;

          // Convert PCM16 data to float samples
          final samples = _convertPcm16ToFloat(data);
          _audioBuffer.addAll(samples);

          // When we have enough samples, send them to the classifier
          if (_audioBuffer.length >= requiredSamples) {
            // Convert to Float32List for TFLite
            final samples = Float32List.fromList(
              _audioBuffer.sublist(0, requiredSamples),
            );
            onAudioBuffer(samples);

            // Keep 25% overlap for continuous processing
            final overlapSize = (requiredSamples * 0.25).round();
            _audioBuffer = _audioBuffer.sublist(
              _audioBuffer.length - overlapSize,
            );
          }
        },
        onError: (error) {
          debugPrint('❌ Recording error: $error');
          stopRecording();
        },
      );
    } catch (e) {
      _isRecording = false;
      debugPrint('❌ Failed to start recording: $e');
      rethrow;
    }
  }

  List<double> _convertPcm16ToFloat(List<int> pcmData) {
    final samples = <double>[];

    // Process PCM16 data (2 bytes per sample, little-endian)
    for (int i = 0; i < pcmData.length - 1; i += 2) {
      int sample = (pcmData[i + 1] << 8) | pcmData[i];
      // Convert from signed 16-bit integer to float in range [-1, 1]
      if (sample > 32767) sample -= 65536;
      samples.add(sample / 32768.0);
    }

    return samples;
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;

    debugPrint('🛑 Stopping audio recording...');
    try {
      _isRecording = false;
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;

      await _audioRecorder.stop();
      _audioBuffer.clear();
      debugPrint('✅ Recording stopped');
    } catch (e) {
      debugPrint('❌ Error stopping recording: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {
    debugPrint('🧹 Cleaning up AudioCaptureService...');
    try {
      await stopRecording();
      _audioRecorder.dispose();
      _isInitialized = false;
      debugPrint('✅ AudioCaptureService cleanup complete');
    } catch (e) {
      debugPrint('❌ Error during cleanup: $e');
      rethrow;
    }
  }

  // Service state
  bool get isRecording => _isRecording;
  bool get isInitialized => _isInitialized;
}
