import { useState, useEffect, useRef } from "react";
import { useAppStore, SensorData } from "./app-store";
import demoData from "../assets/data2.json";

export const useDemoData = () => {
  const [isDemoActive, setIsDemoActive] = useState(false);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [demoSpeed, setDemoSpeed] = useState(200); // milliseconds per data point
  const intervalRef = useRef<NodeJS.Timeout | null>(null);
  const currentIndexRef = useRef<number>(0); // Add ref to track current index
  const updateSensorData = useAppStore((state) => state.updateSensorData);
  const setBandConnected = useAppStore((state) => state.setBandConnected);

  // Convert array data to SensorData object
  const convertToSensorData = (data: number[]): SensorData => {
    return {
      gyroAccel: {
        meanX: data[0],
        stdDevX: data[1],
        meanY: data[2],
        stdDevY: data[3],
        meanZ: data[4],
        stdDevZ: data[5],
      },
      gyroVelocity: {
        meanX: data[6],
        stdDevX: data[7],
        meanY: data[8],
        stdDevY: data[9],
        meanZ: data[10],
        stdDevZ: data[11],
      },
      accel: {
        meanX: data[12],
        stdDevX: data[13],
        meanY: data[14],
        stdDevY: data[15],
        meanZ: data[16],
        stdDevZ: data[17],
      },
      heartRate: data[18],
      skinTemperature: data[19],
      deltaPedometer: data[20],
      deltaDistance: data[21],
      speed: data[22],
      pace: data[23],
      deltaCalories: data[24],
      uv: data[25],
      rawGyro: {
        x: data[6],
        y: data[8],
        z: data[10],
      },
      rawAccel: {
        x: data[12],
        y: data[14],
        z: data[16],
      },
    };
  };

  // Update the currentIndexRef whenever currentIndex changes
  useEffect(() => {
    currentIndexRef.current = currentIndex;
  }, [currentIndex]);

  const startDemo = () => {
    if (isDemoActive) return;

    // Set device as connected when demo starts
    setBandConnected("connected");
    setIsDemoActive(true);
    setCurrentIndex(0);
    currentIndexRef.current = 0; // Reset the ref as well

    // Start processing demo data using the ref for current index
    intervalRef.current = setInterval(() => {
      const idx = currentIndexRef.current;

      if (idx < demoData.length) {
        const dataPoint = demoData[idx];
        const sensorData = convertToSensorData(dataPoint);
        updateSensorData(sensorData);

        // Update both the ref and the state
        const nextIndex = (idx + 1) % demoData.length;
        currentIndexRef.current = nextIndex;
        setCurrentIndex(nextIndex);
      }
    }, demoSpeed);
  };

  const stopDemo = () => {
    if (intervalRef.current) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
    setIsDemoActive(false);
    setBandConnected("disconnected");
  };

  const changeDemoSpeed = (newSpeed: number) => {
    setDemoSpeed(newSpeed);
    if (isDemoActive && intervalRef.current) {
      clearInterval(intervalRef.current);

      // Recreate the interval with the updated speed
      intervalRef.current = setInterval(() => {
        const idx = currentIndexRef.current;

        if (idx < demoData.length) {
          const dataPoint = demoData[idx];
          const sensorData = convertToSensorData(dataPoint);
          updateSensorData(sensorData);

          // Update both the ref and the state
          const nextIndex = (idx + 1) % demoData.length;
          currentIndexRef.current = nextIndex;
          setCurrentIndex(nextIndex);
        }
      }, newSpeed);
    }
  };

  // Clean up on unmount
  useEffect(() => {
    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
    };
  }, []);

  return {
    isDemoActive,
    currentIndex,
    demoSpeed,
    startDemo,
    stopDemo,
    changeDemoSpeed,
    totalDataPoints: demoData.length,
  };
};
