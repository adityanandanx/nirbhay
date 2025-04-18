import { TriangleAlertIcon } from "lucide-react-native";
import React, { useCallback, useEffect } from "react";
import { TouchableOpacity, View } from "react-native";
import { Box } from "../ui/box";
import { HStack } from "../ui/hstack";
import { Icon } from "../ui/icon";
import { Text } from "../ui/text";
import { Toast, ToastTitle, useToast } from "../ui/toast";
import { VStack } from "../ui/vstack";
import { Image } from "expo-image";
import { useAppStore } from "@/lib/app-store";
import { useDeviceActions } from "@/lib/useDeviceActions";
import { Button, ButtonText } from "../ui/button";

type Props = {};

const Shield = (props: Props) => {
  const shieldState = useAppStore((state) => state.shieldState);
  const toggleShield = useAppStore((state) => state.toggleShield);
  const deviceConnectionState = useAppStore(
    (state) => state.deviceConnectionState
  );
  const { sensorData } = useDeviceActions();
  const { demo } = useDeviceActions();

  const toast = useToast();

  // Automatic shield activation based on sensor readings
  useEffect(() => {
    // Only check when shield is activated and device is connected
    if (shieldState === "active" && deviceConnectionState === "connected") {
      const heartRateHigh = sensorData.heartRate > 100;
      const highAcceleration =
        Math.abs(sensorData.rawAccel.x) > 1.5 ||
        Math.abs(sensorData.rawAccel.y) > 1.5 ||
        Math.abs(sensorData.rawAccel.z) > 1.5;

      // Show alert if heart rate is high or sudden acceleration is detected
      if (heartRateHigh || highAcceleration) {
        toast.show({
          placement: "top",
          render: ({ id }) => {
            const toastId = "toast-alert-" + id;
            return (
              <Toast
                nativeID={toastId}
                className="py-0 px-4 gap-2 shadow-soft-1 items-center flex-row bg-error-500"
              >
                <Icon
                  as={TriangleAlertIcon}
                  size="xl"
                  className="stroke-typography-100"
                />
                <ToastTitle className="py-4" size="sm">
                  {heartRateHigh
                    ? "High heart rate detected!"
                    : "Sudden movement detected!"}
                </ToastTitle>
              </Toast>
            );
          },
        });
      }
    }
  }, [sensorData, shieldState, deviceConnectionState]);

  const handlePress = () => {
    if (deviceConnectionState !== "connected") {
      toast.show({
        placement: "bottom",
        render: ({ id }) => {
          const toastId = "toast-" + id;
          return (
            <Toast
              nativeID={toastId}
              className="py-0 px-4 gap-2 shadow-soft-1 items-center flex-row bg-background-900"
            >
              <Icon
                as={TriangleAlertIcon}
                size="xl"
                className="stroke-typography-100"
              />
              <ToastTitle className="py-4" size="sm">
                Please connect the band
              </ToastTitle>
            </Toast>
          );
        },
      });
      return;
    }
    toggleShield();
  };

  const loadShieldIcon = useCallback(() => {
    if (shieldState === "inactive") {
      return require("@/assets/images/shield-icon-inactive.svg");
    } else if (shieldState === "active") {
      return require("@/assets/images/shield-icon-active.svg");
    } else if (shieldState === "standby") {
      return require("@/assets/images/shield-icon-standby.svg");
    }
  }, [shieldState]);

  return (
    <TouchableOpacity
      onPress={handlePress}
      activeOpacity={0.9}
      className="items-center gap-4"
    >
      <VStack space="md" className="items-center">
        {/* Shield Icon */}
        <Box className="w-64 h-64">
          <Image
            style={{ width: "100%", height: "100%" }}
            alt="shield icon"
            contentFit="contain"
            transition={250}
            source={loadShieldIcon()}
          />
        </Box>
        <HStack space="sm" className="items-center">
          {/* Label Indicator */}
          <View
            className={`w-4 h-4 rounded-full ${
              shieldState === "active"
                ? "bg-success-500"
                : shieldState === "inactive"
                ? "bg-error-500"
                : "bg-warning-500"
            }`}
          />
          {/* Label */}
          <Text className="uppercase font-bold">
            {(() => {
              switch (shieldState) {
                case "inactive":
                  return "unsafe";
                case "active":
                  return "active";
                case "standby":
                  return "standby";
              }
            })()}
          </Text>
        </HStack>

        {/* Heartrate indicator when shield is active */}
        {shieldState === "active" && (
          <HStack space="sm" className="items-center">
            <Icon
              as={TriangleAlertIcon}
              size="sm"
              className={
                sensorData.heartRate > 100
                  ? "stroke-error-500"
                  : "stroke-success-500"
              }
            />
            <Text
              className={
                sensorData.heartRate > 100
                  ? "text-error-500"
                  : "text-success-500"
              }
            >
              {sensorData.heartRate.toFixed(0)} BPM
            </Text>
          </HStack>
        )}
      </VStack>
    </TouchableOpacity>
  );
};

export default Shield;
