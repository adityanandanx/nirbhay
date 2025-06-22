# ESP32-S3 BLE Setup for Nirbhay Flutter App

This document provides instructions for setting up your ESP32-S3 to work with the Nirbhay Flutter app via Bluetooth Low Energy (BLE).

## ESP32-S3 Arduino Code

Here's a basic Arduino sketch for your ESP32-S3 that creates a BLE server compatible with the Flutter app:

```cpp
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// Device and service identifiers (must match Flutter app)
#define DEVICE_NAME "Nirbhay_Device"
#define SERVICE_UUID "12345678-1234-1234-1234-123456789abc"
#define CHARACTERISTIC_UUID "87654321-4321-4321-4321-cba987654321"

BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// Mock sensor data
float heartRate = 75.0;
float temperature = 36.5;
bool emergencyButton = false;

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("Device Connected");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("Device Disconnected");
    }
};

class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String rxValue = pCharacteristic->getValue();

      if (rxValue.length() > 0) {
        Serial.println("Received Value: " + rxValue);

        // Handle commands from Flutter app
        if (rxValue == "GET_STATUS") {
          sendSensorData();
        } else if (rxValue == "EMERGENCY_ACK") {
          emergencyButton = false;
          Serial.println("Emergency acknowledged");
        }
      }
    }
};

void setup() {
  Serial.begin(115200);
  Serial.println("Starting BLE Server...");

  // Create the BLE Device
  BLEDevice::init(DEVICE_NAME);

  // Create the BLE Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create the BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create a BLE Characteristic
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ   |
                      BLECharacteristic::PROPERTY_WRITE  |
                      BLECharacteristic::PROPERTY_NOTIFY |
                      BLECharacteristic::PROPERTY_INDICATE
                    );

  pCharacteristic->setCallbacks(new MyCallbacks());

  // Start the service
  pService->start();

  // Start advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(false);
  pAdvertising->setMinPreferred(0x0);
  BLEDevice::startAdvertising();

  Serial.println("Characteristic defined! Now you can read/write it in your Flutter app");
}

void loop() {
  // Simulate sensor readings
  heartRate += random(-2, 3);
  if (heartRate < 60) heartRate = 60;
  if (heartRate > 100) heartRate = 100;

  temperature += random(-1, 2) * 0.1;
  if (temperature < 36.0) temperature = 36.0;
  if (temperature > 37.5) temperature = 37.5;

  // Simulate emergency button press (for testing)
  if (random(0, 1000) < 5) { // 0.5% chance per loop
    emergencyButton = true;
    Serial.println("Emergency button pressed!");
  }

  if (deviceConnected) {
    sendSensorData();

    // Send emergency alert if button pressed
    if (emergencyButton) {
      sendEmergencyAlert();
    }

    delay(2000); // Send data every 2 seconds
  }

  // Handle connection changes
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    Serial.println("Start advertising");
    oldDeviceConnected = deviceConnected;
  }

  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }
}

void sendSensorData() {
  if (pCharacteristic) {
    // Create JSON-like string
    String data = "{";
    data += "\"heartRate\":" + String(heartRate) + ",";
    data += "\"temperature\":" + String(temperature) + ",";
    data += "\"battery\":85,";
    data += "\"timestamp\":" + String(millis());
    data += "}";

    pCharacteristic->setValue(data.c_str());
    pCharacteristic->notify();

    Serial.println("Sent: " + data);
  }
}

void sendEmergencyAlert() {
  if (pCharacteristic) {
    String alert = "{\"emergency\":true,\"timestamp\":" + String(millis()) + "}";
    pCharacteristic->setValue(alert.c_str());
    pCharacteristic->notify();

    Serial.println("Emergency Alert Sent: " + alert);
  }
}
```

## Hardware Setup

### Required Components:

1. ESP32-S3 development board
2. Emergency button (optional)
3. LED indicators (optional)
4. Breadboard and jumper wires

### Wiring (Optional Components):

- Emergency Button: Connect to GPIO 0 (with pull-up resistor)
- Status LED: Connect to GPIO 2
- Power LED: Connect to GPIO 4

## Arduino IDE Setup

1. **Install ESP32 Board Package:**

   - Open Arduino IDE
   - Go to File → Preferences
   - Add this URL to "Additional Board Manager URLs":
     ```
     https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
     ```
   - Go to Tools → Board → Board Manager
   - Search for "ESP32" and install "ESP32 by Espressif Systems"

2. **Install Required Libraries:**

   - Go to Sketch → Include Library → Manage Libraries
   - Search and install:
     - "ESP32 BLE Arduino" (if not included with ESP32 package)

3. **Board Settings:**
   - Board: "ESP32S3 Dev Module"
   - USB CDC On Boot: "Enabled"
   - Flash Size: "4MB (32Mb)"
   - Partition Scheme: "Default 4MB with spiffs"

## Testing the Connection

1. Upload the Arduino code to your ESP32-S3
2. Open the Serial Monitor (115200 baud rate)
3. You should see "Starting BLE Server..." message
4. Open your Flutter app and navigate to the BLE Connection screen
5. Tap "Start Scanning" - you should see "Nirbhay_Device" in the list
6. Tap "Connect" next to the device
7. Once connected, you should see sensor data being received

## Customization

### Changing Device Name:

Update the `DEVICE_NAME` constant in the Arduino code and the corresponding value in the Flutter app's `BLEService` class.

### Adding Real Sensors:

Replace the mock sensor data with actual sensor readings:

- Heart rate sensor (MAX30102)
- Temperature sensor (DS18B20)
- Accelerometer/Gyroscope (MPU6050)
- GPS module (NEO-6M)

### Security Features:

For production use, consider adding:

- BLE pairing and bonding
- Data encryption
- Authentication tokens

## Troubleshooting

**Device not found:**

- Ensure ESP32 is powered and running
- Check if Bluetooth is enabled on your phone
- Make sure the device name matches exactly

**Connection issues:**

- Reset the ESP32 and try again
- Clear Bluetooth cache on your phone
- Check the UUIDs match between Arduino and Flutter code

**No data received:**

- Check Serial Monitor for any errors
- Verify the characteristic UUID is correct
- Ensure notifications are enabled

## Data Format

The ESP32 sends data in JSON format:

```json
{
  "heartRate": 75.0,
  "temperature": 36.5,
  "battery": 85,
  "timestamp": 12345678
}
```

Emergency alerts:

```json
{
  "emergency": true,
  "timestamp": 12345678
}
```
