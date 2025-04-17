import { useEffect, useState } from "react";
import { useAppStore } from "./app-store";
import RNBluetoothClassic from "react-native-bluetooth-classic";

export const useDeviceActions = () => {
  const device = useAppStore((state) => state.device);
  const onDeviceDisconnected = useAppStore(
    (state) => state.onDeviceDisconnected
  );

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

    // Setup data received handler
    const dataSub = device.onDataReceived((event) => {
      console.log("Received data:", event.data);
      setData(event.data);
    });

    // Setup disconnection handler
    const disconnectSub = RNBluetoothClassic.onDeviceDisconnected((e) => {
      console.log(e);

      console.log("Device disconnected");
      onDeviceDisconnected();
    });

    return () => {
      dataSub.remove();
      disconnectSub.remove();
    };
  }, [device, onDeviceDisconnected]);

  useEffect(() => {
    const spldata = data.split(" ");
    setBpm(parseFloat(spldata[0]));
  }, [data]);

  return { sendData, bpm };
};
