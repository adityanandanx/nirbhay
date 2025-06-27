import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BLEService {
  static final BLEService _instance = BLEService._internal();
  factory BLEService() => _instance;
  BLEService._internal();

  // ESP32-S3 Device Information
  static const String deviceName =
      "Nirbhay_Device"; // Change this to your ESP32 device name
  static const String serviceUUID =
      "12345678-1234-1234-1234-123456789abc"; // Your service UUID
  static const String characteristicUUID =
      "87654321-4321-4321-4321-cba987654321"; // Your characteristic UUID

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _characteristicSubscription;

  // Connection state stream
  final StreamController<BluetoothConnectionState> _connectionStateController =
      StreamController<BluetoothConnectionState>.broadcast();
  Stream<BluetoothConnectionState> get connectionState =>
      _connectionStateController.stream;

  // Data stream from device
  final StreamController<Map<String, dynamic>> _dataController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;

  bool get isConnected => _connectedDevice != null;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  /// Check and request BLE permissions
  Future<bool> checkPermissions() async {
    Map<Permission, PermissionStatus> statuses =
        await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
          Permission.locationWhenInUse,
        ].request();

    bool allGranted = statuses.values.every(
      (status) => status == PermissionStatus.granted,
    );

    if (!allGranted) {
      debugPrint("Some BLE permissions were denied");
      for (var entry in statuses.entries) {
        debugPrint("${entry.key}: ${entry.value}");
      }
    }

    return allGranted;
  }

  /// Initialize BLE and check if supported
  Future<bool> initialize() async {
    try {
      if (await FlutterBluePlus.isSupported == false) {
        debugPrint("Bluetooth not supported by this device");
        return false;
      }

      // Check if Bluetooth is on
      BluetoothAdapterState adapterState =
          await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        debugPrint("Bluetooth is not turned on");
        return false;
      }

      return await checkPermissions();
    } catch (e) {
      debugPrint("Error initializing BLE: $e");
      return false;
    }
  }

  /// Start scanning for ESP32-S3 devices
  Future<List<BluetoothDevice>> startScan({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    List<BluetoothDevice> foundDevices = [];

    try {
      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: true,
      );

      // Listen to scan results
      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          BluetoothDevice device = result.device;

          // Filter for our ESP32 device
          if (device.platformName.isNotEmpty &&
              (device.platformName.contains("Nirbhay") ||
                  device.platformName.contains("ESP32") ||
                  device.platformName == deviceName)) {
            if (!foundDevices.any((d) => d.remoteId == device.remoteId)) {
              foundDevices.add(device);
              debugPrint(
                "Found device: ${device.platformName} - ${device.remoteId}",
              );
            }
          }
        }
      });

      // Wait for scan to complete
      await FlutterBluePlus.isScanning.where((val) => val == false).first;

      return foundDevices;
    } catch (e) {
      debugPrint("Error during scan: $e");
      return foundDevices;
    }
  }

  /// Connect to a specific ESP32-S3 device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      // Disconnect from any previous device
      await disconnect();

      debugPrint("Connecting to device: ${device.platformName}");

      // Connect to device
      await device.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = device;

      // Listen to connection state changes
      _connectionSubscription = device.connectionState.listen((state) {
        debugPrint("Connection state: $state");
        _connectionStateController.add(state);

        if (state == BluetoothConnectionState.disconnected) {
          _cleanup();
        }
      });

      // Discover services
      List<BluetoothService> services = await device.discoverServices();

      // Find our service and characteristic
      BluetoothService? targetService;
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() ==
            serviceUUID.toLowerCase()) {
          targetService = service;
          break;
        }
      }

      if (targetService != null) {
        for (BluetoothCharacteristic characteristic
            in targetService.characteristics) {
          if (characteristic.uuid.toString().toLowerCase() ==
              characteristicUUID.toLowerCase()) {
            _characteristic = characteristic;

            // Enable notifications if supported
            if (characteristic.properties.notify) {
              await characteristic.setNotifyValue(true);

              // Listen to characteristic updates
              _characteristicSubscription = characteristic.lastValueStream
                  .listen((value) {
                    _handleIncomingData(value);
                  });
            }
            break;
          }
        }
      }

      debugPrint("Successfully connected to ${device.platformName}");
      return true;
    } catch (e) {
      debugPrint("Error connecting to device: $e");
      _cleanup();
      return false;
    }
  }

  /// Send data to ESP32-S3
  Future<bool> sendData(Map<String, dynamic> data) async {
    if (_characteristic == null || !_characteristic!.properties.write) {
      debugPrint(
        "Cannot send data: characteristic not available or not writable",
      );
      return false;
    }

    try {
      String jsonData = json.encode(data);
      List<int> bytes = utf8.encode(jsonData);

      await _characteristic!.write(bytes, withoutResponse: false);
      debugPrint("Sent data: $jsonData");
      return true;
    } catch (e) {
      debugPrint("Error sending data: $e");
      return false;
    }
  }

  /// Send emergency alert to device
  Future<bool> sendEmergencyAlert() async {
    return await sendData({'emergency': true});
  }

  /// Send safety mode toggle
  Future<bool> setSafetyMode(bool enabled) async {
    return await sendData({
      'type': 'safety_mode',
      'enabled': enabled,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Request device status
  Future<bool> requestDeviceStatus() async {
    return await sendData({
      'type': 'status_request',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Send emergency timer signal to device
  Future<bool> sendEmergencyTimer(int countdownSeconds) async {
    return await sendData({
      'type': 'emergency_timer',
      'countdown': countdownSeconds,
    });
  }

  /// Handle incoming data from ESP32-S3
  void _handleIncomingData(List<int> value) {
    try {
      String data = utf8.decode(value);
      debugPrint("Received data: $data");

      // Parse JSON data from ESP32
      Map<String, dynamic> parsedData = json.decode(data);

      // Check for emergency cancel response
      if (parsedData.containsKey('emergency_response') &&
          parsedData['emergency_response'] == 'cancel') {
        parsedData['emergency_cancelled'] = true;
      }

      _dataController.add(parsedData);
    } catch (e) {
      debugPrint("Error parsing received data: $e");
    }
  }

  /// Disconnect from device
  Future<void> disconnect() async {
    try {
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
      _cleanup();
    } catch (e) {
      debugPrint("Error disconnecting: $e");
      _cleanup();
    }
  }

  /// Cleanup connections and subscriptions
  void _cleanup() {
    _connectionSubscription?.cancel();
    _characteristicSubscription?.cancel();
    _connectionSubscription = null;
    _characteristicSubscription = null;
    _connectedDevice = null;
    _characteristic = null;
  }

  /// Dispose of the service
  void dispose() {
    _cleanup();
    _connectionStateController.close();
    _dataController.close();
  }
}
