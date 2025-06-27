import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nirbhay_flutter/widgets/speech_to_text_test.dart';
import 'dart:async';

import '../../providers/app_providers.dart';
import '../../providers/user_provider.dart';
import '../../widgets/audio_classifier_test.dart';
import '../../widgets/location_map_section.dart';
import '../../widgets/quick_actions_section.dart';
import '../../widgets/safety_status_card.dart';
import '../../widgets/sos_button.dart';
import '../../widgets/triangle_of_safety_section.dart';
import '../../widgets/wearable_status_card.dart';
import '../ble_connection_screen.dart';
import '../../services/fight_flight_predictor.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _predictionTimer;
  final List<List<double>> _sensorDataBuffer = [];
  final FightFlightPredictor _predictor = FightFlightPredictor();
  StreamSubscription? _bleDataSubscription;

  @override
  void initState() {
    super.initState();
    // Initialize BLE when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Initialize BLE via the provider
      await ref.read(bleStateProvider.notifier).initialize();

      // Load the predictor model in advance
      await _predictor.load();

      // Setup data collection and prediction timer
      _setupBLEDataCollection();
      _setupPredictionTimer();
    });
  }

  void _setupBLEDataCollection() {
    // Monitor BLE state for sensor data updates
    _bleDataSubscription = ref.read(bleStateProvider.notifier).stream.listen((
      bleState,
    ) {
      if (bleState.sensorData != null &&
          ref.read(safetyStateProvider).isSafetyModeActive) {
        _processBLEData(bleState.sensorData!);
      }
    });
  }

  void _processBLEData(Map<String, dynamic> data) {
    // Convert JSON data to the format expected by the predictor
    // Format: [hr, ax, ay, az, gx, gy, gz]
    try {
      final List<double> sensorReading = [];

      // Add heart rate
      sensorReading.add(data['heartRate']?.toDouble() ?? 0.0);

      // Add accelerometer data
      if (data['accel'] != null) {
        sensorReading.add(data['accel']['x']?.toDouble() ?? 0.0);
        sensorReading.add(data['accel']['y']?.toDouble() ?? 0.0);
        sensorReading.add(data['accel']['z']?.toDouble() ?? 0.0);
      } else {
        sensorReading.addAll([0.0, 0.0, 0.0]);
      }

      // Add gyroscope data
      if (data['gyro'] != null) {
        sensorReading.add(data['gyro']['x']?.toDouble() ?? 0.0);
        sensorReading.add(data['gyro']['y']?.toDouble() ?? 0.0);
        sensorReading.add(data['gyro']['z']?.toDouble() ?? 0.0);
      } else {
        sensorReading.addAll([0.0, 0.0, 0.0]);
      }

      // Add to buffer
      _sensorDataBuffer.add(sensorReading);

      // Keep only the most recent 8 readings
      if (_sensorDataBuffer.length > 8) {
        _sensorDataBuffer.removeAt(0);
      }
    } catch (e) {
      print('Error processing BLE data: $e');
    }
  }

  void _setupPredictionTimer() {
    _predictionTimer = Timer.periodic(const Duration(seconds: 10), (
      timer,
    ) async {
      // Only run prediction if safety mode is active and we have enough data
      if (ref.read(safetyStateProvider).isSafetyModeActive &&
          _sensorDataBuffer.length == 8) {
        try {
          // Clone the buffer to avoid modification during prediction
          final batchData = List<List<double>>.from(_sensorDataBuffer);
          final result = await _predictor.predict(batchData);
          debugPrint("PREDICTED $result");

          // Handle the prediction result
          _handlePredictionResult(result);
        } catch (e) {
          print('Error during fight/flight prediction: $e');
        }
      }
    });
  }

  void _handlePredictionResult(String result) {
    // If the result indicates fight-or-flight response, show an alert
    if (result.contains('Atypical')) {
      // Log the detection
      debugPrint('Fight-or-flight response detected: $result');

      // Optionally show a notification to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Detected potential stress response: $result'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  void dispose() {
    _predictionTimer?.cancel();
    _bleDataSubscription?.cancel();
    super.dispose();
  }

  void _navigateToBLEConnection() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const BLEConnectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with greeting
              // User greeting with actual name
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Get user data from provider
                      Consumer(
                        builder: (context, ref, child) {
                          // Get the current user data
                          final userData = ref.watch(userDataProvider);

                          return userData.when(
                            loading:
                                () => Text(
                                  'Hello there',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                            error:
                                (_, __) => Text(
                                  'Hello there',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                            data: (userModel) {
                              // Get first name from full name
                              final fullName =
                                  userModel?.displayName ?? 'there';
                              final firstName = fullName.split(' ').first;

                              return Text(
                                'Hello, $firstName',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Stay safe, stay protected',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  // Notification bell
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.notifications_outlined,
                      color: Colors.grey.shade700,
                      size: 24,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),
              // Big SOS Button (only visible when safety mode is active)
              const SOSButton(),
              if (ref.watch(safetyStateProvider).isSafetyModeActive)
                const SizedBox(height: 30),
              // Safety Status Card
              const SafetyStatusCard(),
              const SizedBox(height: 30),

              // Wearable Status
              WearableStatusCard(onManageDevice: _navigateToBLEConnection),
              const SizedBox(height: 30),

              // Location Map Section (new addition)
              const LocationMapSection(),
              const SizedBox(height: 30),

              // Quick Actions
              const QuickActionsSection(),
              const SizedBox(height: 30),

              // Triangle of Safety Section
              const TriangleOfSafetySection(),
              const SizedBox(height: 30),

              // Audio Classifier Test Widget
              const AudioClassifierTest(),
              const SizedBox(height: 30),

              // Audio Classifier Test Widget
              const SpeechToTextTest(),
              const SizedBox(height: 30),

              // Test Button for FightFlightPredictor
              Center(
                child: ElevatedButton(
                  onPressed: () async {
                    // Example: 8 sensor readings, each with 7 values [hr, ax, ay, az, gx, gy, gz]
                    List<List<double>> batch = [
                      [80, 0.1, 0.2, 0.3, 10, 11, 12],
                      [82, 0.2, 0.1, 0.3, 12, 10, 13],
                      [78, 0.1, 0.3, 0.2, 11, 12, 10],
                      [85, 0.2, 0.2, 0.2, 13, 14, 15],
                      [90, 0.3, 0.1, 0.2, 15, 13, 12],
                      [88, 0.2, 0.2, 0.1, 14, 15, 13],
                      [86, 0.1, 0.2, 0.3, 12, 11, 14],
                      [84, 0.2, 0.3, 0.1, 13, 12, 15],
                    ];
                    final predictor = FightFlightPredictor();
                    String result = await predictor.predict(batch);
                    // ignore: use_build_context_synchronously
                    showDialog(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: Text('Fight/Flight Prediction'),
                            content: Text(result),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text('OK'),
                              ),
                            ],
                          ),
                    );
                  },
                  child: Text('Test Fight/Flight Predictor'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
