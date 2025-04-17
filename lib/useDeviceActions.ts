import { useEffect, useState } from "react";
import { useAppStore } from "./app-store";

export const useDeviceActions = () => {
  const device = useAppStore((state) => state.device);
  const [data, setData] = useState("");
  const [bpm, setBpm] = useState(0.0);

  const sendData = async (data: any) => {
    if (!device) {
      throw new Error("Device is not connected");
    }

    try {
      await device.write("hello world", "ascii");
    } catch (error) {
      console.error("Error sending data to device:", error);
    }
  };

  useEffect(() => {
    if (!device) return;
    const sub = device.onDataReceived((event) => {
      console.log("Received data:", event.data);
      setData(event.data);
    });

    return () => {
      sub.remove();
    };
  }, [device]);

  useEffect(() => {
    const spldata = data.split(" ");
    setBpm(parseFloat(spldata[0]));
  }, [data]);

  return { sendData, bpm };
};
