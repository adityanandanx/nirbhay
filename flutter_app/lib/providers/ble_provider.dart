import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_service.dart';

// BLE State Model
class BLEState {
  final BluetoothConnectionState connectionState;
  final List<BluetoothDevice> availableDevices;
  final BluetoothDevice? connectedDevice;
  final Map<String, dynamic>? sensorData;
  final bool isScanning;
  final bool isLoading;
  final String? error;

  const BLEState({
    this.connectionState = BluetoothConnectionState.disconnected,
    this.availableDevices = const [],
    this.connectedDevice,
    this.sensorData,
    this.isScanning = false,
    this.isLoading = false,
    this.error,
  });

  BLEState copyWith({
    BluetoothConnectionState? connectionState,
    List<BluetoothDevice>? availableDevices,
    BluetoothDevice? connectedDevice,
    Map<String, dynamic>? sensorData,
    bool? isScanning,
    bool? isLoading,
    String? error,
  }) {
    return BLEState(
      connectionState: connectionState ?? this.connectionState,
      availableDevices: availableDevices ?? this.availableDevices,
      connectedDevice: connectedDevice ?? this.connectedDevice,
      sensorData: sensorData ?? this.sensorData,
      isScanning: isScanning ?? this.isScanning,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  bool get isConnected => connectionState == BluetoothConnectionState.connected;

  String get connectionStatus {
    switch (connectionState) {
      case BluetoothConnectionState.connected:
        return 'Connected';
      case BluetoothConnectionState.connecting:
        return 'Connecting...';
      case BluetoothConnectionState.disconnecting:
        return 'Disconnecting...';
      case BluetoothConnectionState.disconnected:
        return 'Not Connected';
    }
  }
}

// BLE State Notifier
class BLEStateNotifier extends StateNotifier<BLEState> {
  BLEStateNotifier(this._bleService) : super(const BLEState()) {
    _init();
  }

  final BLEService _bleService;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<Map<String, dynamic>>? _dataSubscription;

  void _init() {
    // Listen to connection state changes
    _connectionSubscription = _bleService.connectionState.listen((
      connectionState,
    ) {
      state = state.copyWith(
        connectionState: connectionState,
        connectedDevice: _bleService.connectedDevice,
      );
    });

    // Listen to sensor data
    _dataSubscription = _bleService.dataStream.listen((data) {
      state = state.copyWith(sensorData: data);
    });
  }

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final success = await _bleService.initialize();
      if (!success) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to initialize Bluetooth',
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> startScanning() async {
    if (state.isScanning) return;

    state = state.copyWith(isScanning: true, error: null);
    try {
      final devices = await _bleService.startScan();
      state = state.copyWith(availableDevices: devices, isScanning: false);
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        error: 'Scan failed: ${e.toString()}',
      );
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final success = await _bleService.connectToDevice(device);
      if (success) {
        state = state.copyWith(
          isLoading: false,
          connectedDevice: device,
          connectionState: BluetoothConnectionState.connected,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to connect to device',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Connection failed: ${e.toString()}',
      );
    }
  }

  Future<void> disconnect() async {
    state = state.copyWith(isLoading: true);
    try {
      await _bleService.disconnect();
      state = state.copyWith(
        isLoading: false,
        connectedDevice: null,
        connectionState: BluetoothConnectionState.disconnected,
        sensorData: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Disconnect failed: ${e.toString()}',
      );
    }
  }

  Future<void> sendEmergencyAlert() async {
    try {
      await _bleService.sendEmergencyAlert();
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to send emergency alert: ${e.toString()}',
      );
    }
  }

  Future<void> setSafetyMode(bool enabled) async {
    // Check if device is connected before attempting to set safety mode
    if (!state.isConnected) {
      state = state.copyWith(
        error:
            'Cannot set safety mode: No device connected. Please connect your wearable device first.',
      );
      return;
    }

    try {
      await _bleService.setSafetyMode(enabled);
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to set safety mode: ${e.toString()}',
      );
    }
  }

  Future<void> requestDeviceStatus() async {
    try {
      await _bleService.requestDeviceStatus();
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to request device status: ${e.toString()}',
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _dataSubscription?.cancel();
    super.dispose();
  }
}
