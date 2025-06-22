import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_service.dart';

class BLEConnectionScreen extends StatefulWidget {
  const BLEConnectionScreen({super.key});

  @override
  State<BLEConnectionScreen> createState() => _BLEConnectionScreenState();
}

class _BLEConnectionScreenState extends State<BLEConnectionScreen> {
  final BLEService _bleService = BLEService();
  List<BluetoothDevice> _foundDevices = [];
  bool _isScanning = false;
  bool _isConnecting = false;
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  Map<String, dynamic>? _lastReceivedData;

  @override
  void initState() {
    super.initState();
    _initializeBLE();
    _listenToConnectionState();
    _listenToDataStream();
  }

  void _initializeBLE() async {
    bool initialized = await _bleService.initialize();
    if (!initialized) {
      _showErrorDialog(
        "Bluetooth initialization failed. Please check permissions and Bluetooth settings.",
      );
    }
  }

  void _listenToConnectionState() {
    _bleService.connectionState.listen((state) {
      setState(() {
        _connectionState = state;
      });
    });
  }

  void _listenToDataStream() {
    _bleService.dataStream.listen((data) {
      setState(() {
        _lastReceivedData = data;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Connect Wearable Device',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection Status Card
            _buildConnectionStatusCard(),
            const SizedBox(height: 24),

            // Device Data Card (if connected)
            if (_bleService.isConnected && _lastReceivedData != null)
              _buildDataCard(),

            if (_bleService.isConnected && _lastReceivedData != null)
              const SizedBox(height: 24),

            // Scan Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Devices',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _startScan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon:
                      _isScanning
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(Icons.search),
                  label: Text(_isScanning ? 'Scanning...' : 'Scan'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Device List
            Expanded(
              child:
                  _foundDevices.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                        itemCount: _foundDevices.length,
                        itemBuilder: (context, index) {
                          final device = _foundDevices[index];
                          return _buildDeviceCard(device);
                        },
                      ),
            ),

            // Control Buttons (if connected)
            if (_bleService.isConnected) _buildControlButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatusCard() {
    MaterialColor statusColor;
    IconData statusIcon;
    String statusText;
    String statusDescription;

    switch (_connectionState) {
      case BluetoothConnectionState.connected:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Connected';
        statusDescription = 'Your wearable device is connected and ready';
        break;
      case BluetoothConnectionState.connecting:
        statusColor = Colors.orange;
        statusIcon = Icons.sync;
        statusText = 'Connecting...';
        statusDescription = 'Establishing connection with your device';
        break;
      default:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = 'Disconnected';
        statusDescription = 'No wearable device connected';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor.shade400, statusColor.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(statusIcon, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          Text(
            statusText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            statusDescription,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          if (_bleService.isConnected &&
              _bleService.connectedDevice != null) ...[
            const SizedBox(height: 12),
            Text(
              'Device: ${_bleService.connectedDevice!.platformName}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDataCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sensors, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Device Data',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._lastReceivedData!.entries
              .map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        entry.value.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(BluetoothDevice device) {
    bool isConnected = _bleService.connectedDevice?.remoteId == device.remoteId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isConnected ? Border.all(color: Colors.green, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isConnected ? Colors.green.shade100 : Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.watch,
              color: isConnected ? Colors.green.shade600 : Colors.blue.shade600,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.platformName.isNotEmpty
                      ? device.platformName
                      : 'Unknown Device',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  device.remoteId.toString(),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (isConnected) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Connected',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ElevatedButton(
            onPressed:
                _isConnecting
                    ? null
                    : () => isConnected ? _disconnect() : _connect(device),
            style: ElevatedButton.styleFrom(
              backgroundColor: isConnected ? Colors.red : Colors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child:
                _isConnecting
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : Text(isConnected ? 'Disconnect' : 'Connect'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bluetooth_searching,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No devices found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure your wearable device is on and in pairing mode',
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _bleService.sendEmergencyAlert(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.emergency),
                label: const Text('Test Alert'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _bleService.requestDeviceStatus(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Status'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _startScan() async {
    setState(() {
      _isScanning = true;
      _foundDevices.clear();
    });

    try {
      List<BluetoothDevice> devices = await _bleService.startScan();
      setState(() {
        _foundDevices = devices;
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      _showErrorDialog("Scan failed: $e");
    }
  }

  void _connect(BluetoothDevice device) async {
    setState(() {
      _isConnecting = true;
    });

    bool success = await _bleService.connectToDevice(device);

    setState(() {
      _isConnecting = false;
    });

    if (!success) {
      _showErrorDialog("Failed to connect to ${device.platformName}");
    }
  }

  void _disconnect() async {
    await _bleService.disconnect();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
