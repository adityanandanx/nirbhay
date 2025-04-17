import { create } from "zustand";
import { PermissionsAndroid } from "react-native";
import RNBluetoothClassic, {
  BluetoothDevice,
} from "react-native-bluetooth-classic";

export type BandConnectionState = "connected" | "connecting" | "disconnected";
export type ShieldState = "active" | "inactive" | "standby";

type AppState = {
  deviceConnectionState: BandConnectionState;
  device: BluetoothDevice | null;
  deviceBatteryPercentage: number;
  heartRate: number;
  shieldState: ShieldState;
};

type AppStateActions = {
  toggleShield: () => void;
  setBandConnected: (state: BandConnectionState) => void;
  connectToDevice: () => Promise<void>;
  requestBluetoothPermissions: () => Promise<boolean>;
  requestAccessFineLocationPermission: () => Promise<boolean>;
  onDeviceDisconnected: () => void;
};

type AppStore = AppState & AppStateActions;

export const useAppStore = create<AppStore>((set, get) => ({
  deviceConnectionState: "disconnected",
  deviceBatteryPercentage: 0,
  heartRate: 0,
  shieldState: "inactive",
  device: null,

  onDeviceDisconnected: () => {
    set({
      deviceConnectionState: "disconnected",
      shieldState: "inactive",
      device: null,
      heartRate: 0.0,
    });
  },

  toggleShield() {
    set((state) => ({
      shieldState: state.shieldState === "active" ? "standby" : "active",
    }));
  },

  setBandConnected(state: BandConnectionState) {
    const shieldState: ShieldState =
      state === "connected" ? "standby" : "inactive";
    set({ deviceConnectionState: state, shieldState });
  },

  requestBluetoothPermissions: async () => {
    const granted = await PermissionsAndroid.request(
      PermissionsAndroid.PERMISSIONS.BLUETOOTH_CONNECT,
      {
        title: "Access bluetooth required for discovery",
        message:
          "In order to perform discovery, you must enable/allow " +
          "bluetooth access.",
        buttonNeutral: "Ask Me Later",
        buttonNegative: "Cancel",
        buttonPositive: "OK",
      }
    );
    return granted === PermissionsAndroid.RESULTS.GRANTED;
  },

  requestAccessFineLocationPermission: async () => {
    const granted = await PermissionsAndroid.request(
      PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION,
      {
        title: "Access fine location required for discovery",
        message:
          "In order to perform discovery, you must enable/allow " +
          "fine location access.",
        buttonNeutral: "Ask Me Later",
        buttonNegative: "Cancel",
        buttonPositive: "OK",
      }
    );
    return granted === PermissionsAndroid.RESULTS.GRANTED;
  },

  connectToDevice: async () => {
    const hasBluetoothPermission = await get().requestBluetoothPermissions();
    if (!hasBluetoothPermission) {
      console.log("Bluetooth permission denied");
      set({ deviceConnectionState: "disconnected" });
      return;
    }
    const hasLocationPermission =
      await get().requestAccessFineLocationPermission();
    if (!hasLocationPermission) {
      console.log("Location permission denied");
      set({ deviceConnectionState: "disconnected" });
      return;
    }

    try {
      set({ deviceConnectionState: "connecting" });
      const pairedDevices = await RNBluetoothClassic.getBondedDevices();
      console.log("Paired devices:", pairedDevices.length);
      let device = pairedDevices.find((d) => d.name === "HC-05");

      if (!device) {
        console.log("Starting discovery...");
        const devices = await RNBluetoothClassic.startDiscovery();
        console.log("Discovered devices", devices.length);
        devices.forEach((d) => {
          console.log(d.name, d.address);
        });
        device = devices.find((d) => d.name === "HC-05");
        console.log("Found device:", device);
      }

      if (!device) {
        console.log("Device not found");
        set({ deviceConnectionState: "disconnected" });
        return;
      }

      if (!device.bonded) {
        try {
          console.log("Pairing with device...");
          await RNBluetoothClassic.pairDevice(device.address);
          console.log("Pairing complete");
        } catch (pairError) {
          // Device might already be paired, continue with connection
          console.log("Pairing error or already paired:", pairError);
        }
      }

      console.log("Connecting to device...");
      await device.connect();
      console.log("Connected to device");
      console.log("Checking connection status...");
      const isConnected = await device.isConnected();
      console.log("Device connected:", isConnected);

      if (isConnected) {
        set({
          deviceConnectionState: "connected",
          shieldState: "standby",
          device,
        });
      } else {
        throw new Error("Failed to connect to device");
      }
    } catch (error) {
      console.error("Error connecting to device:", error);
      set({ deviceConnectionState: "disconnected", shieldState: "inactive" });
    }
  },
}));
