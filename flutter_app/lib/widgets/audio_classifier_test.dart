import 'package:flutter/material.dart';
import '../services/continuous_audio_classifier.dart';

class AudioClassifierTest extends StatefulWidget {
  const AudioClassifierTest({super.key});

  @override
  State<AudioClassifierTest> createState() => _AudioClassifierTestState();
}

class _AudioClassifierTestState extends State<AudioClassifierTest> {
  late final ContinuousAudioClassifier _classifier;
  bool _isInitialized = false;
  bool _isClassifying = false;
  String _lastDetectedSound = 'None';
  double _lastConfidence = 0.0;

  @override
  void initState() {
    super.initState();
    _classifier = ContinuousAudioClassifier(
      onSoundDetected: (label, confidence) {
        setState(() {
          _lastDetectedSound = label;
          _lastConfidence = confidence;
        });
      },
    );
  }

  Future<void> _initialize() async {
    try {
      await _classifier.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Failed to initialize classifier: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize audio classifier: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleClassification() async {
    if (!_isInitialized) {
      await _initialize();
    }

    try {
      if (_isClassifying) {
        await _classifier.stopClassification();
      } else {
        await _classifier.startClassification();
      }

      setState(() {
        _isClassifying = !_isClassifying;
      });
    } catch (e) {
      debugPrint('Error toggling classification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _classifier.dispose();
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
              'Audio Classification Test',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Status:', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  _isClassifying ? 'Listening' : 'Stopped',
                  style: TextStyle(
                    color: _isClassifying ? Colors.green : Colors.red,
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
                  'Last Detected:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Flexible(
                  child: Text(
                    _lastDetectedSound,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Confidence:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${(_lastConfidence * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _toggleClassification,
              icon: Icon(_isClassifying ? Icons.stop : Icons.mic),
              label: Text(_isClassifying ? 'Stop' : 'Start'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isClassifying ? Colors.red : Colors.green,
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
