#include <Arduino.h>
#include "Arduino_GFX_Library.h"
#include <Arduino.h>
#include "pin_config.h"
#include <Wire.h>
#include "MAX30105.h"
#include "heartRate.h"
#include "spo2_algorithm.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "SensorQMI8658.hpp"
#include "Arduino_DriveBus_Library.h"
#include <ArduinoJson.h>
// Device and service identifiers
#define DEVICE_NAME "Nirbhay_Device"
#define SERVICE_UUID "12345678-1234-1234-1234-123456789abc"
#define CHARACTERISTIC_UUID "87654321-4321-4321-4321-cba987654321"

// Initialize MAX30102 sensor
MAX30105 particleSensor;

// BLE variables
BLEServer *pServer = NULL;
BLECharacteristic *pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;
bool emergencyButton = false;
// Display setup
Arduino_DataBus *bus = new Arduino_ESP32SPI(LCD_DC, LCD_CS, LCD_SCK, LCD_MOSI);
Arduino_GFX *gfx = new Arduino_ST7789(bus, LCD_RST /* RST */,
                                      0 /* rotation */, true /* IPS */, LCD_WIDTH, LCD_HEIGHT, 0, 20, 0, 0);

// Touch sensor setup
std::shared_ptr<Arduino_IIC_DriveBus> IIC_Bus =
    std::make_shared<Arduino_HWIIC>(IIC_SDA, IIC_SCL, &Wire);

void Arduino_IIC_Touch_Interrupt(void);

std::unique_ptr<Arduino_IIC> CST816T(new Arduino_CST816x(IIC_Bus, CST816T_DEVICE_ADDRESS,
                                                         TP_RST, TP_INT, Arduino_IIC_Touch_Interrupt));

void Arduino_IIC_Touch_Interrupt(void)
{
  CST816T->IIC_Interrupt_Flag = true;
}
bool touchInProgress = false;

// Heart rate calculation variables
const byte RATE_SIZE = 4; // Increase for more averaging
byte rates[RATE_SIZE];    // Array of heart rates
byte rateSpot = 0;
long lastBeat = 0; // Time at which the last beat occurred
float beatsPerMinute;
int beatAvg;

// Finger presence detection variables
long unblockedValue = 0; // Average IR at power up
bool fingerPresent = false;
bool previousFingerPresent = false; // To track finger presence changes

// SpO2 calculation variables
// uint32_t irBuffer[100];  // infrared LED sensor data
// uint32_t redBuffer[100]; // red LED sensor data
// int32_t bufferLength = 50;
// int32_t spo2 = 0;
// int8_t validSPO2 = 0; // indicator to show if the SPO2 calculation is valid
// int32_t heartRate = 0;
// int8_t validHeartRate = 0; // indicator to show if the heart rate calculation is valid

// Timing variables
unsigned long lastSpO2Check = 0;
unsigned long lastDisplay = 0;
unsigned long lastBLEUpdate = 0;
bool initialSPO2Done = false;
bool collectingSpo2 = false;
int spo2Index = 0;
unsigned long sampleTimestamp = 0;

// IMU sensor and data variables
SensorQMI8658 qmi;
IMUdata acc; // Acceleration data
IMUdata gyr; // Gyroscope data
bool imuInitialized = false;
unsigned long lastIMUCheck = 0;

bool demoMode = false;
unsigned long demoStartTime = 0;
unsigned long demoDuration = 20000; // 15 seconds of demo

// Demo button location and size
#define DEMO_BUTTON_X 70  // Center bottom placement
#define DEMO_BUTTON_Y 110 // Near bottom of screen
#define DEMO_BUTTON_W 140 // Make it wide enough to tap easily
#define DEMO_BUTTON_H 40  // Make it tall enough to tap easily
int32_t lastTouchX = 0;
int32_t lastTouchY = 0;
bool touchActive = false;
unsigned long lastTouchTime = 0;
void drawDemoButton(bool active)
{
  gfx->fillRect(DEMO_BUTTON_X - 2, DEMO_BUTTON_Y - 2, DEMO_BUTTON_W + 4, DEMO_BUTTON_H + 4, BLACK);

  if (active)
  {
    gfx->fillRoundRect(DEMO_BUTTON_X, DEMO_BUTTON_Y, DEMO_BUTTON_W, DEMO_BUTTON_H, 8, RED);
  }
  else
  {
    gfx->fillRoundRect(DEMO_BUTTON_X, DEMO_BUTTON_Y, DEMO_BUTTON_W, DEMO_BUTTON_H, 8, BLUE);
  }

  gfx->setTextColor(WHITE);
  gfx->setTextSize(2); // Larger text for better visibility

  // Center the text in the button
  if (active)
  {
    gfx->setCursor(DEMO_BUTTON_X + 15, DEMO_BUTTON_Y + 12);
    gfx->println("STOP DEMO");
  }
  else
  {
    gfx->setCursor(DEMO_BUTTON_X + 25, DEMO_BUTTON_Y + 12);
    gfx->println("DEMO");
  }
}
bool isTouchInDemoButton(int32_t x, int32_t y)
{
  return (x >= DEMO_BUTTON_X && x <= DEMO_BUTTON_X + DEMO_BUTTON_W &&
          y >= DEMO_BUTTON_Y && y <= DEMO_BUTTON_Y + DEMO_BUTTON_H);
}
bool emergencyActive = false;
unsigned long emergencyStartTime = 0;
const unsigned long EMERGENCY_TIMEOUT = 10000; // 10 seconds timeout
bool sosTriggered = false;

// Safety button definitions
#define SAFETY_BUTTON_X 60
#define SAFETY_BUTTON_Y 140
#define SAFETY_BUTTON_W 200
#define SAFETY_BUTTON_H 60

// Add these helper functions after your existing button functions
void drawSafetyButton()
{
  gfx->fillRoundRect(SAFETY_BUTTON_X, SAFETY_BUTTON_Y, SAFETY_BUTTON_W, SAFETY_BUTTON_H, 10, WHITE);
  gfx->drawRoundRect(SAFETY_BUTTON_X, SAFETY_BUTTON_Y, SAFETY_BUTTON_W, SAFETY_BUTTON_H, 10, BLACK);

  gfx->setTextColor(BLACK);
  gfx->setTextSize(2);
  gfx->setCursor(SAFETY_BUTTON_X + 30, SAFETY_BUTTON_Y + 20);
  gfx->println("I AM SAFE");
}

bool isTouchInSafetyButton(int32_t x, int32_t y)
{
  bool isInButton = (x >= SAFETY_BUTTON_X && x <= SAFETY_BUTTON_X + SAFETY_BUTTON_W &&
                     y >= SAFETY_BUTTON_Y && y <= SAFETY_BUTTON_Y + SAFETY_BUTTON_H);

  if (isInButton)
  {
    Serial.printf("Touch in safety button: X=%d, Y=%d\n", x, y);
  }
  return isInButton;
}
void sendSensorData()
{
  if (!pCharacteristic || emergencyActive)
    return; // Don't send data during emergency

  String data = "{";
  // Add demo mode status
  data += "\"demo\":" + String(demoMode ? "true" : "false") + ",";
  data += "\"heartRate\":" + String(beatAvg > 0 ? beatAvg : 0) + ",";
  data += "\"fingerPresent\":" + String(fingerPresent ? "true" : "false") + ",";

  if (imuInitialized)
  {
    data += "\"accel\":{";
    data += "\"x\":" + String(acc.x) + ",";
    data += "\"y\":" + String(acc.y) + ",";
    data += "\"z\":" + String(acc.z);
    data += "},";

    data += "\"gyro\":{";
    data += "\"x\":" + String(gyr.x) + ",";
    data += "\"y\":" + String(gyr.y) + ",";
    data += "\"z\":" + String(gyr.z);
    data += "}";
  }
  data += "}";

  pCharacteristic->setValue(data.c_str());
  pCharacteristic->notify();
}

// BLE callbacks
class MyServerCallbacks : public BLEServerCallbacks
{
  void onConnect(BLEServer *pServer)
  {
    deviceConnected = true;
    Serial.println("Device Connected");
  };

  void onDisconnect(BLEServer *pServer)
  {
    deviceConnected = false;
    Serial.println("Device Disconnected");
  }
};

int emergencyCountdown = 10; // Default countdown in seconds

// Replace your existing MyCallbacks class
class MyCallbacks : public BLECharacteristicCallbacks
{
  void onWrite(BLECharacteristic *pCharacteristic)
  {
    std::string rxValueStd = pCharacteristic->getValue();

    if (rxValueStd.length() > 0)
    {
      String rxValue = String(rxValueStd.c_str());
      Serial.println("Received Value: " + rxValue);

      StaticJsonDocument<200> doc;
      DeserializationError error = deserializeJson(doc, rxValue);

      if (!error)
      {
        // Check if this is an emergency timer message
        if (doc["type"] == "emergency_timer")
        {
          emergencyActive = true;
          emergencyStartTime = millis();
          emergencyCountdown = doc["countdown"] | 10;
          Serial.println("Emergency countdown started: " + String(emergencyCountdown) + " seconds");
        }
      }
    }
  }
};

void setup()
{
  Serial.begin(115200);
  Serial.println("MAX30102 Heart Rate and SpO2 Monitor");

  // Initialize display
  if (!gfx->begin())
  {
    Serial.println("gfx->begin() failed!");
  }

  gfx->fillScreen(BLACK);
  pinMode(LCD_BL, OUTPUT);
  digitalWrite(LCD_BL, HIGH);

  // Display startup message
  gfx->setCursor(10, 10);
  gfx->setTextColor(WHITE);
  gfx->setTextSize(2);
  gfx->println("Nirbhay Device");
  gfx->setCursor(10, 40);
  gfx->println("Initializing...");

  // Initialize I2C
  Wire.begin(11, 10); // SCL=11, SDA=10

  // Initialize sensor
  if (particleSensor.begin(Wire, I2C_SPEED_FAST) == false)
  {
    Serial.println("MAX30102 was not found. Check wiring.");

    gfx->fillScreen(BLACK);
    gfx->setCursor(10, 10);
    gfx->setTextColor(RED);
    gfx->setTextSize(2);
    gfx->println("Sensor Error!");
    gfx->setCursor(10, 40);
    gfx->println("Check wiring");

    while (1)
      ; // Stop execution
  }

  // Sensor found
  gfx->fillScreen(BLACK);
  gfx->setCursor(10, 10);
  gfx->setTextColor(GREEN);
  gfx->setTextSize(2);
  gfx->println("Sensor Found!");

  // Configuring sensor
  byte ledBrightness = 60;
  byte sampleAverage = 8;
  byte ledMode = 2;
  byte sampleRate = 100;
  int pulseWidth = 411;
  int adcRange = 4096;

  particleSensor.setup(ledBrightness, sampleAverage, ledMode, sampleRate, pulseWidth, adcRange);
  particleSensor.setPulseAmplitudeRed(0x0A); // Turn Red LED to low to indicate sensor is running
  particleSensor.setPulseAmplitudeIR(0x1F);  // IR intensity
  particleSensor.setPulseAmplitudeGreen(0);

  // Take an average of IR readings at power up for finger detection (from presence.ino)
  unblockedValue = 0;
  for (byte x = 0; x < 32; x++)
  {
    unblockedValue += particleSensor.getIR(); // Read the IR value
  }
  unblockedValue /= 32;

  Serial.println("Initializing IMU sensor...");
  if (qmi.begin(Wire, QMI8658_L_SLAVE_ADDRESS, IIC_SDA, IIC_SCL))
  {
    imuInitialized = true;
    Serial.println("IMU initialized successfully");

    // Get chip id
    Serial.print("IMU Chip ID: ");
    Serial.println(qmi.getChipID());

    // Configure accelerometer

    qmi.configAccelerometer(
        SensorQMI8658::ACC_RANGE_4G,
        SensorQMI8658::ACC_ODR_1000Hz,
        SensorQMI8658::LPF_MODE_0,
        true);

    qmi.configGyroscope(
        SensorQMI8658::GYR_RANGE_64DPS,
        SensorQMI8658::GYR_ODR_896_8Hz,
        SensorQMI8658::LPF_MODE_3,
        true);

    qmi.enableGyroscope();
    qmi.enableAccelerometer();

    gfx->setCursor(10, 160);
    gfx->setTextColor(GREEN);
    gfx->println("IMU Ready!");
  }
  else
  {
    Serial.println("Failed to initialize IMU");
    gfx->setCursor(10, 160);
    gfx->setTextColor(RED);
    gfx->println("IMU Error!");
  }

  // Initialize BLE
  gfx->setCursor(10, 40);
  gfx->println("Starting BLE...");

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
      BLECharacteristic::PROPERTY_READ |
          BLECharacteristic::PROPERTY_WRITE |
          BLECharacteristic::PROPERTY_NOTIFY |
          BLECharacteristic::PROPERTY_INDICATE);

  pCharacteristic->setCallbacks(new MyCallbacks());
  pCharacteristic->addDescriptor(new BLE2902());

  // Start the service
  pService->start();

  // Start advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(false);
  pAdvertising->setMinPreferred(0x0);
  BLEDevice::startAdvertising();

  gfx->setCursor(10, 70);
  gfx->println("BLE Ready!");
  gfx->setCursor(10, 100);
  gfx->println("Place finger");
  gfx->setCursor(10, 130);
  gfx->println("on sensor");

  delay(1000);
}
void simulateDemoData(unsigned long currentMillis)
{
  float demoProgress = (float)(currentMillis - demoStartTime) / demoDuration;

  // Heart rate simulation remains same
  if (demoProgress < 0.2)
  {
    beatAvg = 70 + (int)(60.0 * demoProgress / 0.2);
  }
  else
  {
    beatAvg = 130 + random(-5, 6);
    emergencyButton = true;
  }

  // Enhanced motion simulation
  if (imuInitialized)
  {
    // Increase base intensity
    float intensityFactor = 5.0; // Increased base intensity

    // Make movement more dramatic during emergency
    if (demoProgress > 0.2 && demoProgress < 0.6)
    {
      intensityFactor = 8.0; // Much stronger during emergency phase
    }

    float phase = demoProgress * 2 * PI * 4; // Increased frequency

    // More dramatic accelerometer data (like violent shaking or falling)
    acc.x = sin(phase * 8) * 4.0 * intensityFactor + random(-20, 21) / 10.0;
    acc.y = cos(phase * 9) * 3.6 * intensityFactor + random(-20, 21) / 10.0;
    acc.z = sin(phase * 7 + PI / 3) * 4.4 * intensityFactor + random(-20, 21) / 10.0;

    // More dramatic gyroscope data (like rapid spinning)
    gyr.x = sin(phase * 5) * 40.0 * intensityFactor + random(-10, 11);
    gyr.y = cos(phase * 6) * 35.0 * intensityFactor + random(-10, 11);
    gyr.z = sin(phase * 4.5) * 45.0 * intensityFactor + random(-10, 11);
  }
}
// void simulateDemoData(unsigned long currentMillis)
// {
//   float demoProgress = (float)(currentMillis - demoStartTime) / demoDuration;
//   if (demoProgress < 0.2)
//   {
//     // Quick rise (0-20% of demo time)
//     beatAvg = 70 + (int)(60.0 * demoProgress / 0.2);
//   }
//   else
//   {
//     beatAvg = 130 + random(-5, 6);
//     emergencyButton = true;
//   }

//   // Simulate SpO2 drop
//   // if (demoProgress < 0.2)
//   // {
//   //   spo2 = 98 - (int)(10.0 * demoProgress / 0.2);
//   // }
//   // else
//   // {
//   //   spo2 = 88 + random(-2, 3);
//   //   validSPO2 = 1;
//   // }
//   // validSPO2 = 1;

//   // Simulate accelerometer and gyroscope data
//   if (imuInitialized)
//   {
//     float intensityFactor = 1.0;
//     if (demoProgress > 0.2 && demoProgress < 0.6)
//     {
//       intensityFactor = 3.0;
//     }

//     float phase = demoProgress * 2 * PI * 2;

//     // Simulate accelerometer data (like someone is shaking or falling)
//     acc.x = sin(phase * 5) * 2.0 * intensityFactor + random(-10, 11) / 10.0;
//     acc.y = cos(phase * 6) * 1.8 * intensityFactor + random(-10, 11) / 10.0;
//     acc.z = sin(phase * 4 + PI / 4) * 2.2 * intensityFactor + random(-10, 11) / 10.0;

//     // Simulate gyroscope data (like device is rotating)
//     gyr.x = sin(phase * 3) * 20.0 * intensityFactor + random(-5, 6);
//     gyr.y = cos(phase * 4) * 15.0 * intensityFactor + random(-5, 6);
//     gyr.z = sin(phase * 2.5) * 25.0 * intensityFactor + random(-5, 6);
//   }
// }

void loop()
{
  unsigned long currentMillis = millis();
  int32_t touchX = CST816T->IIC_Read_Device_Value(CST816T->Arduino_IIC_Touch::Value_Information::TOUCH_COORDINATE_X);
  int32_t touchY = CST816T->IIC_Read_Device_Value(CST816T->Arduino_IIC_Touch::Value_Information::TOUCH_COORDINATE_Y);
  bool currentTouch = (touchX > 0 && touchY > 0);

  if (currentTouch)
  {
    Serial.printf("Touch detected at X:%d Y:%d\n", touchX, touchY);
  }
  if (currentTouch && !touchInProgress && (currentMillis - lastTouchTime > 300))
  {
    touchInProgress = true;
    lastTouchTime = currentMillis;
    if (currentTouch)
    {
      gfx->fillCircle(touchX, touchY, 3, RED);
      Serial.printf("Touch at X:%d Y:%d, Demo button: X:%d-%d Y:%d-%d\n",
                    touchX, touchY,
                    DEMO_BUTTON_X, DEMO_BUTTON_X + DEMO_BUTTON_W,
                    DEMO_BUTTON_Y, DEMO_BUTTON_Y + DEMO_BUTTON_H);
    }

    if (isTouchInDemoButton(touchX, touchY))
    {
      // Toggle demo mode
      demoMode = !demoMode;

      if (demoMode)
      {
        // Start demo mode
        demoStartTime = currentMillis;
        Serial.println("Demo mode activated!");
      }
      else
      {
        // Exit demo mode
        emergencyButton = false;
        Serial.println("Demo mode deactivated!");
      }
    }
  }
  else if (!currentTouch && touchInProgress)
  {
    // Touch just ended
    touchInProgress = false;
  }
  if (demoMode && (currentMillis - demoStartTime > demoDuration))
  {
    demoMode = false;
    emergencyButton = false; // Clear emergency when demo ends
    Serial.println("Demo mode ended automatically");
  }

  // If in demo mode, simulate data instead of reading from sensors
  if (demoMode)
  {
    simulateDemoData(currentMillis);
    fingerPresent = true; // Force finger presence during demo
  }
  // Get the latest sensor readings
  uint32_t red = particleSensor.getRed();
  uint32_t ir = particleSensor.getIR();

  // Check finger presence (using presence.ino method)
  long currentDelta = ir - unblockedValue;
  previousFingerPresent = fingerPresent;
  fingerPresent = (currentDelta > 50000);

  // Detect change in finger presence status
  bool fingerStatusChanged = (previousFingerPresent != fingerPresent);

  // If finger was removed, immediately reset values and update display/send data
  if (fingerStatusChanged && !fingerPresent)
  {
    beatAvg = 0;
    beatsPerMinute = 0;
    // validSPO2 = 0;
    // spo2 = 0;

    // Force immediate display update
    lastDisplay = 0;

    // Send data immediately to report finger removed
    if (deviceConnected)
    {
      sendSensorData();
    }
  }
  if (imuInitialized && (currentMillis - lastIMUCheck > 50))
  {
    lastIMUCheck = currentMillis;

    if (qmi.getDataReady())
    {
      // Read accelerometer data
      if (qmi.getAccelerometer(acc.x, acc.y, acc.z))
      {
        Serial.print("ACCEL: x=");
        Serial.print(acc.x);
        Serial.print(", y=");
        Serial.print(acc.y);
        Serial.print(", z=");
        Serial.println(acc.z);
      }

      // Read gyroscope data
      if (qmi.getGyroscope(gyr.x, gyr.y, gyr.z))
      {
        Serial.print("GYRO: x=");
        Serial.print(gyr.x);
        Serial.print(", y=");
        Serial.print(gyr.y);
        Serial.print(", z=");
        Serial.println(gyr.z);
      }
    }
  }

  if (fingerPresent)
  {
    if (checkForBeat(ir) == true)
    {
      // We sensed a beat!
      long delta = millis() - lastBeat;
      lastBeat = millis();

      beatsPerMinute = 60 / (delta / 1000.0);

      if (beatsPerMinute < 255 && beatsPerMinute > 20)
      {
        rates[rateSpot++] = (byte)beatsPerMinute; // Store this reading in the array
        rateSpot %= RATE_SIZE;                    // Wrap variable

        // Take average of readings
        beatAvg = 0;
        for (byte x = 0; x < RATE_SIZE; x++)
          beatAvg += rates[x];
        beatAvg /= RATE_SIZE;

        // Debug output
        Serial.print("IR=");
        Serial.print(ir);
        Serial.print(", BPM=");
        Serial.print(beatsPerMinute);
        Serial.print(", Avg BPM=");
        Serial.println(beatAvg);
      }
    }

    // Debug IR signal values to troubleshoot
    // Serial.print("IR Signal: ");
    // Serial.print(ir);
    // Serial.print(", Delta: ");
    // Serial.println(ir - unblockedValue);

    // // Combined heart rate and SpO2 processing as in SPO2.ino
    // if (!collectingSpo2 && (currentMillis - lastSpO2Check > 3000 || !initialSPO2Done))
    // {
    //   // Start a new collection cycle
    //   collectingSpo2 = true;
    //   spo2Index = 0;
    //   Serial.println("Starting sample collection for HR and SpO2");
    // }

    // if (collectingSpo2)
    // {
    //   // Only process if sensor has new data AND it's been at least 5ms since last sample
    //   if (particleSensor.available() && currentMillis - sampleTimestamp >= 5)
    //   {
    //     sampleTimestamp = currentMillis;

    //     // Store the current sample
    //     redBuffer[spo2Index] = particleSensor.getRed();
    //     irBuffer[spo2Index] = particleSensor.getIR();
    //     particleSensor.nextSample(); // Important: move to next sample

    //     spo2Index++;

    //     // Check if we've collected enough samples
    //     if (spo2Index >= bufferLength)
    //     {
    //       // Calculate both SpO2 and heart rate using Maxim algorithm
    //       maxim_heart_rate_and_oxygen_saturation(
    //           irBuffer, bufferLength, redBuffer,
    //           &spo2, &validSPO2, &heartRate, &validHeartRate);

    //       // Process heart rate result from SpO2 algorithm
    //       if (validHeartRate)
    //       {
    //         // If the heart rate is valid, update our beatAvg
    //         beatsPerMinute = heartRate;

    //         // Add to our rolling average
    //         rates[rateSpot++] = (byte)beatsPerMinute;
    //         rateSpot %= RATE_SIZE;

    //         // Calculate average
    //         beatAvg = 0;
    //         for (byte x = 0; x < RATE_SIZE; x++)
    //         {
    //           beatAvg += rates[x];
    //         }
    //         beatAvg /= RATE_SIZE;

    //         Serial.print("Valid Heart Rate: ");
    //         Serial.print(heartRate);
    //         Serial.print(", Average: ");
    //         Serial.println(beatAvg);
    //       }

    //       // Constrain SpO2 to reasonable values
    //       if (spo2 > 100)
    //         spo2 = 100;

    //       // Reset collection state
    //       collectingSpo2 = false;
    //       lastSpO2Check = currentMillis;
    //       initialSPO2Done = true;
    //     }
    //   }
    // }

    // // Note: This won't update beatAvg but gives immediate visual feedback
    // if (checkForBeat(ir))
    // {
    //   // Flash indicator or update something on display
    //   Serial.println("♥ Beat!");
    // }
  }
  // else if (collectingSpo2)
  // {
  //   // If finger was removed during collection, cancel it
  //   collectingSpo2 = false;
  //   spo2Index = 0;
  //   Serial.println("Collection canceled - finger removed");
  // }
  if (emergencyActive)
  {
    unsigned long currentMillis = millis();

    // Get fresh touch coordinates
    int32_t touchX = CST816T->IIC_Read_Device_Value(CST816T->Arduino_IIC_Touch::Value_Information::TOUCH_COORDINATE_X);
    int32_t touchY = CST816T->IIC_Read_Device_Value(CST816T->Arduino_IIC_Touch::Value_Information::TOUCH_COORDINATE_Y);
    bool currentTouch = (touchX > 0 && touchY > 0);

    // Debug touch coordinates
    if (currentTouch)
    {
      Serial.printf("Emergency Screen Touch: X=%d, Y=%d\n", touchX, touchY);
    }

    // Handle touch for safety button
    if (currentTouch && !touchInProgress)
    {
      touchInProgress = true;

      if (isTouchInSafetyButton(touchX, touchY))
      {
        // User confirmed they are safe
        emergencyActive = false;
        sosTriggered = false;
        Serial.println("Emergency cancelled by user");

        // Send cancellation to app
        String response = "{\"emergency_response\":\"cancel\"}";
        pCharacteristic->setValue(response.c_str());
        pCharacteristic->notify();

        // Debug print
        Serial.println("Sent to phone: " + response);

        // Reset display
        gfx->fillScreen(BLACK);
        lastDisplay = 0;

        return; // Exit emergency mode
      }
    }
    else if (!currentTouch)
    {
      touchInProgress = false; // Reset touch state when no touch detected
    }

    // Update emergency screen
    if (currentMillis - lastDisplay > 100)
    {
      lastDisplay = currentMillis;

      // Clear screen with red background
      gfx->fillScreen(RED);

      // Draw emergency text
      gfx->setTextColor(WHITE);
      gfx->setTextSize(3);
      gfx->setCursor(20, 40);
      gfx->println("EMERGENCY!");

      // Calculate and show countdown
      int secondsLeft = emergencyCountdown - ((currentMillis - emergencyStartTime) / 1000);
      if (secondsLeft > 0)
      {
        // Show countdown
        gfx->setTextSize(2);
        gfx->setCursor(20, 90);
        gfx->print("SOS in: ");
        gfx->print(secondsLeft);
        gfx->println("s");

        // Draw the safety button
        drawSafetyButton();
      }

      return; // Skip normal display update
    }
  }
  // Updating display
  bool forceUpdate = fingerStatusChanged;
  if (currentMillis - lastDisplay > 500 || fingerStatusChanged)
  {
    lastDisplay = currentMillis;
    gfx->fillScreen(BLACK);

    // Show readings
    gfx->setCursor(10, 10);
    gfx->setTextColor(WHITE);
    gfx->setTextSize(2);

    // Show finger detection
    gfx->setCursor(10, 50);
    if (fingerPresent)
    {
      gfx->setTextColor(GREEN);
      gfx->println("FINGER DETECTED");
    }
    else
    {
      gfx->setTextColor(RED);
      gfx->println("PLACE FINGER");
    }

    // Show heart rate
    gfx->setCursor(10, 90);
    gfx->setTextColor(RED);
    if (demoMode || (beatAvg > 0 && fingerPresent))
    {
      gfx->print("HR: ");
      if (demoMode)
      {
        gfx->print(beatAvg);
        gfx->println(" BPM (DEMO)");
      }
      else
      {
        gfx->print(beatAvg);
        gfx->println(" BPM");
      }
    }
    else
    {
      gfx->println("HR: --");
    }

    // Show SpO2
    // gfx->setCursor(10, 130);
    // gfx->setTextColor(BLUE);
    // if (demoMode || (validSPO2 && fingerPresent))
    // {
    //   gfx->print("SpO2: ");
    //   if (demoMode)
    //   {
    //     gfx->print(spo2);
    //     gfx->println("% (DEMO)");
    //   }
    //   else
    //   {
    //     gfx->print(random(96, 100));
    //     gfx->println("%");
    //   }
    // }
    // else
    // {
    //   gfx->println("SpO2: --");
    // }
    if (imuInitialized)
    {
      gfx->setCursor(10, 190);
      gfx->setTextColor(YELLOW);
      gfx->println("IMU Data:");

      // Accelerometer
      gfx->setCursor(10, 210);
      gfx->setTextSize(2);
      gfx->print("Acc: ");
      gfx->print(acc.x, 1);
      gfx->print(", ");
      gfx->print(acc.y, 1);
      gfx->print(", ");
      gfx->println(acc.z, 1);

      // Gyroscope
      gfx->setCursor(10, 225);
      gfx->print("Gyr: ");
      gfx->print(gyr.x, 1);
      gfx->print(", ");
      gfx->print(gyr.y, 1);
      gfx->print(", ");
      gfx->println(gyr.z, 1);
      gfx->setTextSize(2);
    }
    // Display BLE connection status
    gfx->setCursor(10, 170);
    if (deviceConnected)
    {
      gfx->setTextColor(GREEN);
      gfx->println("BLE: Connected");
    }
    else
    {
      gfx->setTextColor(BLUE);
      gfx->println("BLE: Advertising");
    }

    // // Show emergency alert if active
    // if (emergencyButton)
    // {
    //   gfx->setCursor(10, 210);
    //   gfx->setTextColor(RED);
    //   gfx->println("EMERGENCY ALERT!");
    // }
    drawDemoButton(demoMode);
  }

  // Send data via BLE every 500ms when connected
  if (deviceConnected && (currentMillis - lastBLEUpdate > 500 || fingerStatusChanged))
  {
    lastBLEUpdate = currentMillis;

    // Check for emergency condition
    // Example: SpO2 too low or heart rate outside normal range
    // if (validSPO2 && spo2 < 90 && fingerPresent)
    // {
    //   emergencyButton = true;
    // }

    // if (beatAvg > 120 || (beatAvg < 50 && beatAvg > 0 && fingerPresent))
    // {
    //   emergencyButton = true;
    // }

    // Send all data in one JSON message
    sendSensorData();
  }

  // Handle BLE connection changes
  if (!deviceConnected && oldDeviceConnected)
  {
    delay(500);
    pServer->startAdvertising();
    Serial.println("Start advertising");
    oldDeviceConnected = deviceConnected;
  }

  if (deviceConnected && !oldDeviceConnected)
  {
    oldDeviceConnected = deviceConnected;
  }
}