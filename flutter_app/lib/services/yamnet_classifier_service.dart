import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Service for running YAMNet audio classification using TFLite
class YamnetClassifierService {
  static const int kSampleRate = 16000;
  static const int kWaveformSamples = 15600; // 0.975 seconds at 16kHz
  static const String kModelPath = 'assets/yamnet.tflite';
  static const String kLabelsPath = 'assets/yamnet_labels.txt';

  late final Interpreter _interpreter;
  late final List<String> _labels;
  bool _isInitialized = false;

  // Input and output tensor indices
  late final int _waveformInputIndex;
  late final int _scoresOutputIndex;

  // Input and output shapes
  late final List<int> _inputShape;
  late final List<int> _outputShape;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🎯 Initializing YamnetClassifierService...');

      // Load and initialize the model
      final modelFile = await _loadModel();
      final interpreterOptions = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromFile(
        modelFile,
        options: interpreterOptions,
      );

      // Get input and output details
      final inputDetails = _interpreter.getInputTensor(0);
      final outputDetails = _interpreter.getOutputTensor(0);

      _waveformInputIndex = 0; // YAMNet has single input
      _scoresOutputIndex = 0; // YAMNet has single output

      _inputShape = inputDetails.shape;
      _outputShape = outputDetails.shape;

      debugPrint('📊 Model input shape: $_inputShape');
      debugPrint('📊 Model output shape: $_outputShape');

      // Load class labels
      await _loadLabels();

      _isInitialized = true;
      debugPrint('✅ YamnetClassifierService initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize YamnetClassifierService: $e');
      rethrow;
    }
  }

  Future<File> _loadModel() async {
    final modelFile = File(
      '${(await getApplicationDocumentsDirectory()).path}/yamnet.tflite',
    );

    if (!modelFile.existsSync()) {
      debugPrint('📥 Copying YAMNet model to local storage...');
      final modelBytes = await rootBundle.load(kModelPath);
      await modelFile.writeAsBytes(modelBytes.buffer.asUint8List());
      debugPrint('✅ Model copied successfully');
    }

    return modelFile;
  }

  Future<void> _loadLabels() async {
    try {
      debugPrint('📝 Loading YAMNet labels...');
      final labelText = await rootBundle.loadString(kLabelsPath);
      _labels =
          labelText
              .split('\n')
              .where((label) => label.trim().isNotEmpty)
              .toList();
      debugPrint('✅ Loaded ${_labels.length} sound classes');
    } catch (e) {
      debugPrint('❌ Failed to load labels: $e');
      rethrow;
    }
  }

  /// Classifies audio waveform and returns the detected class with confidence
  Future<(String, double)?> classifyWaveform(Float32List waveform) async {
    if (!_isInitialized) {
      throw StateError('YamnetClassifierService not initialized');
    }

    if (waveform.length != kWaveformSamples) {
      throw ArgumentError(
        'Waveform must be exactly $kWaveformSamples samples '
        '(${kWaveformSamples / kSampleRate} seconds at $kSampleRate Hz). '
        'Got ${waveform.length} samples.',
      );
    }

    try {
      // Prepare input tensor
      final inputArray = [waveform];

      // Prepare output tensor (521 classes)
      final outputBuffer = [List<double>.filled(521, 0.0)];

      // Run inference
      final stopwatch = Stopwatch()..start();
      _interpreter.run(inputArray, outputBuffer);
      stopwatch.stop();

      debugPrint('⚡ Inference time: ${stopwatch.elapsedMilliseconds}ms');

      // Find class with highest confidence
      var maxIndex = 0;
      var maxConfidence = outputBuffer[0][0];

      for (var i = 0; i < outputBuffer[0].length; i++) {
        if (outputBuffer[0][i] > maxConfidence) {
          maxConfidence = outputBuffer[0][i];
          maxIndex = i;
        }
      }

      if (maxIndex < _labels.length) {
        final detectedLabel = _labels[maxIndex];
        debugPrint(
          '🔊 Detected: $detectedLabel (${(maxConfidence * 100).toStringAsFixed(1)}%)',
        );
        return (detectedLabel, maxConfidence);
      }

      return null;
    } catch (e) {
      debugPrint('❌ Classification error: $e');
      return null;
    }
  }

  void dispose() {
    if (_isInitialized) {
      _interpreter.close();
      _isInitialized = false;
    }
  }

  // Getters for service state
  bool get isInitialized => _isInitialized;
  List<String> get labels => List.unmodifiable(_labels);

  // Get required input size for the model
  int get requiredSamples => kWaveformSamples;
  int get sampleRate => kSampleRate;
}
