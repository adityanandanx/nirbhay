import 'package:flutter/material.dart';
import '../services/distress_audio_detection_service.dart';

class AudioClassifierTest extends StatefulWidget {
  const AudioClassifierTest({super.key});

  @override
  State<AudioClassifierTest> createState() => _AudioClassifierTestState();
}

class _AudioClassifierTestState extends State<AudioClassifierTest> {
  late final DistressAudioDetectionService _detector;
  bool _isInitialized = false;
  bool _isListening = false;
  String _lastDetectedSound = 'None';
  double _lastConfidence = 0.0;
  String _lastRecognizedSpeech = '';

  @override
  void initState() {
    super.initState();
    _detector = DistressAudioDetectionService();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _detector.initialize(
        onDistressDetected: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Distress sound detected!'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
        },
        onSpeechRecognized: (speech) {
          if (mounted) {
            setState(() {
              _lastRecognizedSpeech = speech;
            });
          }
        },
        onError: (error) {
          debugPrint('Error in detector: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Failed to initialize detector: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize audio detector: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleDetection() async {
    if (!_isInitialized) {
      await _initialize();
    }

    try {
      if (_isListening) {
        await _detector.stopListening();
      } else {
        await _detector.startListening();
      }

      setState(() {
        _isListening = _detector.isListening;
      });
    } catch (e) {
      debugPrint('Error toggling detection: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _detector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Distress Audio Detection Test',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Status:', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  _isListening ? 'Listening' : 'Stopped',
                  style: TextStyle(
                    color: _isListening ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Last Speech:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Flexible(
                  child: Text(
                    _lastRecognizedSpeech.isEmpty
                        ? 'None'
                        : _lastRecognizedSpeech,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _toggleDetection,
              icon: Icon(_isListening ? Icons.stop : Icons.mic),
              label: Text(_isListening ? 'Stop' : 'Start'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isListening ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
