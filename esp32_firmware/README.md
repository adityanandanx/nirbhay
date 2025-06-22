# Nirbhay IoT Device

A comprehensive IoT safety device with GUI, BLE communication, and sensor integration.

## Project Structure

The project has been modularized into separate files for better organization and maintainability:

### Core Files

- **`main.cpp`** - Main application entry point with setup() and loop()
- **`config.h`** - Global configuration constants and variable declarations
- **`pin_config.h`** - Hardware pin definitions (located in lib/Mylibrary/)

### Hardware Modules

- **`display.h/cpp`** - Display and LVGL initialization and management
- **`sensors.h/cpp`** - IMU sensor handling and data processing
- **`ble_handler.h/cpp`** - BLE server, communication, and callbacks

### User Interface

- **`ui.h/cpp`** - LVGL GUI screens, components, and event handlers

## Features

### Hardware Support
- **Display**: 240x280 ST7789 TFT LCD with LVGL graphics
- **Sensors**: QMI8658 6-axis IMU (accelerometer + gyroscope)
- **Communication**: BLE server for wireless data transmission
- **Emergency**: Dedicated emergency alert system

### GUI Screens

1. **Main Dashboard**
   - Real-time heart rate and temperature display
   - BLE connection status
   - Battery level indicator
   - Quick access emergency button
   - Navigation to other screens

2. **Sensor Data Screen**
   - Live accelerometer data charts (X, Y, Z axes)
   - Numerical sensor readings
   - Real-time data visualization

3. **Emergency Screen**
   - Large emergency alert button
   - Emergency status indicator
   - One-touch alert transmission

4. **Settings Screen**
   - Display brightness control
   - BLE device information
   - System configuration options

### BLE Communication

- **Device Name**: Nirbhay_Device
- **Data Format**: JSON with sensor readings and timestamps
- **Features**: 
  - Real-time sensor data transmission
  - Emergency alert notifications
  - Bidirectional communication
  - Flutter app compatibility

## Build Instructions

1. Open project in PlatformIO
2. Install required libraries (should auto-install from platformio.ini)
3. Build and upload to ESP32 device

## File Dependencies

```
main.cpp
├── config.h
├── display.h → display.cpp
├── sensors.h → sensors.cpp
├── ble_handler.h → ble_handler.cpp
└── ui.h → ui.cpp
```

## Usage

1. Power on the device
2. The main dashboard will appear showing system status
3. Use touch interface to navigate between screens
4. Connect via BLE from Flutter app for remote monitoring
5. Press emergency button when needed for immediate alert

## Development Notes

- All global variables are properly declared in headers and defined in source files
- Event handlers are modular and screen-specific
- Hardware initialization is separated by functionality
- UI components are created in dedicated functions
- Error handling and fallbacks are implemented for sensor failures

## Customization

- Modify `config.h` for timing and device settings
- Update `ui.cpp` for custom GUI layouts and colors
- Extend `sensors.cpp` for additional sensor support
- Enhance `ble_handler.cpp` for new communication features
