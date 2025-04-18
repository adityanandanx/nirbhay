import { useEffect, useState } from "react";
import { useAppStore, SensorData } from "./app-store";
import RNBluetoothClassic from "react-native-bluetooth-classic";

export const useDeviceActions = () => {
  const device = useAppStore((state) => state.device);
  const onDeviceDisconnected = useAppStore(
    (state) => state.onDeviceDisconnected
  );
  const updateSensorData = useAppStore((state) => state.updateSensorData);
  const sensorData = useAppStore((state) => state.sensorData);

  const [rawData, setRawData] = useState("");
  const [lastError, setLastError] = useState<string | null>(null);
  const [dataBuffer, setDataBuffer] = useState<string>("");

  // Send data to the HC-05 device
  const sendData = async (data: string) => {
    if (!device) {
      throw new Error("Device is not connected");
    }

    try {
      await device.write(data, "ascii");
    } catch (error) {
      console.error("Error sending data to device:", error);
      setLastError("Failed to send data to device");
    }
  };

  const parseIncomingData = (data: string) => {
    try {
      // Add more debugging
      console.log("Attempting to parse:", data);

      // Clean the data - remove any unexpected characters
      const cleanData = data.replace(/[^\d,.\-]/g, "");
      console.log("Cleaned data:", cleanData);

      // Split the comma-separated values
      const values = cleanData.split(",");
      console.log("Split values:", values, "Count:", values.length);

      // Check if we have all 26 values
      if (values.length !== 26) {
        console.warn(`Expected 26 values, got ${values.length}: ${cleanData}`);
        return false;
      }

      // Parse each value to numbers with error handling for each value
      const parsedValues = values.map((v, index) => {
        const parsed = parseFloat(v);
        if (isNaN(parsed)) {
          console.warn(`Failed to parse value at index ${index}: "${v}"`);
          return 0;
        }
        return parsed;
      });

      console.log("Parsed values:", parsedValues);

      // Create sensor data object from parsed values - maintain the exact order from specs
      const newSensorData: SensorData = {
        gyroAccel: {
          meanX: parsedValues[0],
          stdDevX: parsedValues[1],
          meanY: parsedValues[2],
          stdDevY: parsedValues[3],
          meanZ: parsedValues[4],
          stdDevZ: parsedValues[5],
        },
        gyroVelocity: {
          meanX: parsedValues[6],
          stdDevX: parsedValues[7],
          meanY: parsedValues[8],
          stdDevY: parsedValues[9],
          meanZ: parsedValues[10],
          stdDevZ: parsedValues[11],
        },
        accel: {
          meanX: parsedValues[12],
          stdDevX: parsedValues[13],
          meanY: parsedValues[14],
          stdDevY: parsedValues[15],
          meanZ: parsedValues[16],
          stdDevZ: parsedValues[17],
        },
        heartRate: parsedValues[18],
        skinTemperature: parsedValues[19],
        deltaPedometer: parsedValues[20],
        deltaDistance: parsedValues[21],
        speed: parsedValues[22],
        pace: parsedValues[23],
        deltaCalories: parsedValues[24],
        uv: parsedValues[25],

        // Also store raw values for display
        rawGyro: {
          x: parsedValues[6], // Using angular velocity as raw gyro values
          y: parsedValues[8],
          z: parsedValues[10],
        },
        rawAccel: {
          x: parsedValues[12],
          y: parsedValues[14],
          z: parsedValues[16],
        },
      };

      console.log("Created sensor data object:", newSensorData);

      // Update the app store with the new sensor data
      updateSensorData(newSensorData);
      return true;
    } catch (error) {
      console.error("Error parsing data:", error, "Raw data:", data);
      setLastError("Failed to parse sensor data");
      return false;
    }
  };

  // Process the data buffer looking for complete packets
  const processBuffer = (buffer: string) => {
    console.log("Processing buffer:", buffer);

    // Look for data packet delimiters - try different options
    let packets;

    // Option 1: Split by newline
    if (buffer.includes("\n")) {
      packets = buffer.split("\n");
      console.log("Split by newline, found packets:", packets.length);
    }
    // Option 2: Split by carriage return
    else if (buffer.includes("\r")) {
      packets = buffer.split("\r");
      console.log("Split by carriage return, found packets:", packets.length);
    }
    // Option 3: Look for specific start/end markers if your device uses them
    else if (buffer.includes("START") && buffer.includes("END")) {
      const regex = /START(.*?)END/g;
      packets = [];
      let match;
      while ((match = regex.exec(buffer)) !== null) {
        packets.push(match[1]);
      }
      console.log("Found START/END packets:", packets.length);
      // Return remaining buffer after the last END
      return buffer.substring(buffer.lastIndexOf("END") + 3);
    }
    // Default: assume everything is one packet if no delimiters found
    else {
      console.log("No delimiters found in buffer");
      return buffer; // Keep accumulating data
    }

    // If we don't have a complete packet yet, keep buffering
    if (packets.length <= 1) {
      return buffer;
    }

    // Process all complete packets except the last one
    for (let i = 0; i < packets.length - 1; i++) {
      const packet = packets[i].trim();
      if (packet) {
        console.log("Processing packet:", packet);
        setRawData(packet);
        parseIncomingData(packet);
      }
    }

    // Return the remaining incomplete packet
    return packets[packets.length - 1];
  };

  useEffect(() => {
    if (!device) return;

    // Setup data received handler
    const dataSub = device.onDataReceived((event) => {
      const receivedData = event.data;
      console.log("Received raw data:", receivedData);

      // Try to parse data immediately if it looks complete
      if (receivedData.split(",").length === 26) {
        console.log("Complete data packet received, parsing directly");
        setRawData(receivedData);
        parseIncomingData(receivedData);
      } else {
        // Otherwise use the buffer approach
        setDataBuffer((prevBuffer) => {
          const updatedBuffer = prevBuffer + receivedData;
          return processBuffer(updatedBuffer);
        });
      }
    });

    // Setup disconnection handler
    const disconnectSub = RNBluetoothClassic.onDeviceDisconnected((e) => {
      console.log("Device disconnected:", e);
      onDeviceDisconnected();
    });

    return () => {
      dataSub.remove();
      disconnectSub.remove();
    };
  }, [device, onDeviceDisconnected, updateSensorData]);

  // Add a debug function to manually test parsing with sample data
  const testParse = (testData: string) => {
    console.log("Testing parse with data:", testData);
    return parseIncomingData(testData);
  };

  return {
    sendData,
    sensorData,
    rawData,
    lastError,
    testParse, // Add this for debugging in the UI
  };
};
