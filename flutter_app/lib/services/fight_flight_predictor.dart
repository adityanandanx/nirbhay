import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class FightFlightPredictor {
  Interpreter? _interpreter;
  List<double>? _mean;
  List<double>? _scale;



  // Load model and scaler params
  Future<void> load() async {
    _interpreter = await Interpreter.fromAsset('assets/fight_flight_detector_with_calibration.tflite');
    final scalerJson = await rootBundle.loadString('assets/scaler_params.json');
    final scalerParams = json.decode(scalerJson);
    _mean = List<double>.from(scalerParams['mean']);
    _scale = List<double>.from(scalerParams['scale']);
  }

  // Feature engineering for a batch of 8 readings
  // Each reading: [hr, ax, ay, az, gx, gy, gz]
  List<double> engineerFeatures(List<List<double>> batch) {
    List<double> hr = batch.map((e) => e[0]).toList();
    List<List<double>> accel = batch.map((e) => e.sublist(1, 4)).toList();
    List<List<double>> gyro = batch.map((e) => e.sublist(4, 7)).toList();

    double avg(List<double> l) => l.reduce((a, b) => a + b) / l.length;
    double std(List<double> l) {
      double m = avg(l);
      return sqrt(l.map((x) => pow(x - m, 2)).reduce((a, b) => a + b) / l.length);
    }

    // RMSSD
    List<double> rr = hr.where((h) => h > 0).map((h) => 60000.0 / h).toList();
    double rmssd = 0.0;
    if (rr.length > 1) {
      List<double> diff = [];
      for (int i = 1; i < rr.length; i++) {
        diff.add(rr[i] - rr[i - 1]);
      }
      rmssd = sqrt(diff.map((d) => d * d).reduce((a, b) => a + b) / diff.length);
    }

    // Accel features
    List<double> accelMag = accel.map((a) => sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2])).toList();
    double avgAccelMag = avg(accelMag);
    double maxAccelMag = accelMag.reduce(max);
    double stdAccelMag = std(accelMag);

    List<double> avgAccel = [0, 1, 2].map((i) => avg(accel.map((a) => a[i]).toList())).toList();
    List<double> stdAccel = [0, 1, 2].map((i) => std(accel.map((a) => a[i]).toList())).toList();

    // Gyro features
    List<double> gyroMag = gyro.map((g) => sqrt(g[0] * g[0] + g[1] * g[1] + g[2] * g[2])).toList();
    double avgGyroMag = avg(gyroMag);
    double maxGyroMag = gyroMag.reduce(max);
    double stdGyroMag = std(gyroMag);

    List<double> avgGyro = [0, 1, 2].map((i) => avg(gyro.map((g) => g[i]).toList())).toList();
    List<double> stdGyro = [0, 1, 2].map((i) => std(gyro.map((g) => g[i]).toList())).toList();

    // HR features
    double avgHr = avg(hr);
    double maxHr = hr.reduce(max);
    double minHr = hr.reduce(min);
    double stdHr = std(hr);

    // Combined indicators
    bool hrStress = (avgHr > 100) && (rmssd < 25.0) && (rmssd > 8.0);
    bool sensorStress = (avgAccelMag > 1.02) && (avgGyroMag > 20.0);

    return [
      avgHr, maxHr, minHr, stdHr, rmssd,
      avgAccelMag, maxAccelMag, stdAccelMag,
      avgAccel[0], avgAccel[1], avgAccel[2], stdAccel[0], stdAccel[1], stdAccel[2],
      avgGyroMag, maxGyroMag, stdGyroMag,
      avgGyro[0], avgGyro[1], avgGyro[2], stdGyro[0], stdGyro[1], stdGyro[2],
      hrStress ? 1.0 : 0.0, sensorStress ? 1.0 : 0.0
    ];
  }

  // Run prediction
  Future<String> predict(List<List<double>> batch) async {
    if (_interpreter == null || _mean == null || _scale == null) {
      await load();
    }
    List<double> features = engineerFeatures(batch);
    // Scale features
    List<double> scaled = List<double>.generate(
      features.length,
      (i) => (features[i] - _mean![i]) / _scale![i],
    );
    var input = [scaled];
    var output = List.filled(1 * 1, 0.0).reshape([1, 1]);
    _interpreter!.run(input, output);
    double probability = output[0][0];
    return probability > 0.5 ? 'Atypical (fight-or-flight)' : 'Typical';
  }
}
