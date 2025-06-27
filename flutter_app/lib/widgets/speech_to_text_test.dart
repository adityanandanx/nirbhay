import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechToTextTest extends StatefulWidget {
  const SpeechToTextTest({super.key});

  @override
  State<SpeechToTextTest> createState() => _SpeechToTextTestState();
}

class _SpeechToTextTestState extends State<SpeechToTextTest> {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onStatus:
            (status) => debugPrint('🎤 Speech recognition status: $status'),
        onError:
            (error) =>
                debugPrint('🎤 Speech recognition error: ${error.errorMsg}'),
      );
      setState(() {});
    } catch (e) {
      debugPrint('Error initializing speech recognition: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize speech recognition: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startListening() async {
    if (!_speechEnabled) {
      debugPrint('Speech recognition not available');
      return;
    }

    try {
      setState(() => _isListening = true);
      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      );
    } catch (e) {
      debugPrint('Error starting speech recognition: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting speech recognition: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speechToText.stop();
      setState(() => _isListening = false);
    } catch (e) {
      debugPrint('Error stopping speech recognition: $e');
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    debugPrint(
      'Speech result: ${result.recognizedWords} (${result.finalResult ? 'final' : 'partial'})',
    );
    setState(() {
      _lastWords = result.recognizedWords;
    });
  }

  @override
  void dispose() {
    _speechToText.cancel();
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
              'Speech Recognition Test',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Status:', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  _speechEnabled
                      ? (_isListening ? 'Listening' : 'Ready')
                      : 'Not Available',
                  style: TextStyle(
                    color:
                        _speechEnabled
                            ? (_isListening ? Colors.green : Colors.orange)
                            : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _lastWords.isEmpty
                    ? 'Tap the microphone button to start...'
                    : _lastWords,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed:
                  _speechEnabled
                      ? (_isListening ? _stopListening : _startListening)
                      : null,
              icon: Icon(_isListening ? Icons.stop : Icons.mic),
              label: Text(_isListening ? 'Stop' : 'Start'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isListening ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                disabledBackgroundColor: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
