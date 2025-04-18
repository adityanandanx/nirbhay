import { Button, ButtonText } from "@/components/ui/button";
import { useAppStore } from "@/lib/app-store";

import {
  BatteryFullIcon,
  HeartIcon,
  Link2Icon,
  Link2OffIcon,
  SearchIcon,
  RotateCwIcon, // for gyroscope
  MoveIcon, // for acceleration
  ThermometerIcon, // for temperature
  FootprintsIcon, // for pedometer
} from "lucide-react-native";
import React from "react";
import { Card } from "../ui/card";
import { HStack } from "../ui/hstack";
import { Icon } from "../ui/icon";
import { Spinner } from "../ui/spinner";
import { Text } from "../ui/text";
import { VStack } from "../ui/vstack";
import { useDeviceActions } from "@/lib/useDeviceActions";

type Props = {};

const BandStatus = (props: Props) => {
  const deviceConnectionState = useAppStore(
    (state) => state.deviceConnectionState
  );
  const connectToDevice = useAppStore((state) => state.connectToDevice);
  const device = useAppStore((state) => state.device);

  const { sensorData } = useDeviceActions();

  const linkIcon =
    deviceConnectionState === "connected"
      ? Link2Icon
      : deviceConnectionState === "disconnected"
      ? Link2OffIcon
      : () => <Spinner />;

  const linkText = (() => {
    switch (deviceConnectionState) {
      case "disconnected":
        return "Band Disconnected";
      case "connected":
        return "Band Connected";
      case "connecting":
        return "Connecting...";
    }
  })();

  const formatVector = (vector: { x: number; y: number; z: number }) => {
    return `x:${vector.x.toFixed(2)} y:${vector.y.toFixed(
      2
    )} z:${vector.z.toFixed(2)}`;
  };

  return (
    <Card size="lg">
      <VStack space="sm" className="items-center">
        {/* Connection Status */}
        <HStack space="sm" className="items-center">
          <Icon as={linkIcon} size="xl" className="stroke-typography-900" />
          <Text size="lg" bold className="text-typography-900">
            {device?.name}
          </Text>
          <Text size="lg" bold className="text-typography-900">
            {linkText}
          </Text>
        </HStack>

        {deviceConnectionState === "connected" && (
          <VStack space="md" className="w-full">
            <HStack space="xl" className="items-center justify-between">
              <HStack space="sm" className="items-center">
                <Icon
                  as={BatteryFullIcon}
                  size="xl"
                  className="stroke-typography-900"
                />
                <Text size="lg" bold className="text-typography-900">
                  57%
                </Text>
              </HStack>

              <HStack space="sm" className="items-center">
                <Icon
                  as={HeartIcon}
                  size="xl"
                  className="stroke-typography-900"
                />
                <Text size="lg" bold className="text-typography-900">
                  {sensorData.heartRate.toFixed(0)} bpm
                </Text>
              </HStack>
            </HStack>

            {/* Sensor Data */}
            <VStack space="sm" className="w-full">
              <HStack space="sm" className="items-center">
                <Icon
                  as={RotateCwIcon}
                  size="lg"
                  className="stroke-typography-900"
                />
                <Text size="sm" className="text-typography-900">
                  Gyro: {formatVector(sensorData.rawGyro)}
                </Text>
              </HStack>

              <HStack space="sm" className="items-center">
                <Icon
                  as={MoveIcon}
                  size="lg"
                  className="stroke-typography-900"
                />
                <Text size="sm" className="text-typography-900">
                  Accel: {formatVector(sensorData.rawAccel)}
                </Text>
              </HStack>

              <HStack space="sm" className="items-center justify-between">
                <HStack space="sm" className="items-center">
                  <Icon
                    as={ThermometerIcon}
                    size="lg"
                    className="stroke-typography-900"
                  />
                  <Text size="sm" className="text-typography-900">
                    {sensorData.skinTemperature.toFixed(1)} °C
                  </Text>
                </HStack>

                <HStack space="sm" className="items-center">
                  <Icon
                    as={FootprintsIcon}
                    size="lg"
                    className="stroke-typography-900"
                  />
                  <Text size="sm" className="text-typography-900">
                    {sensorData.deltaPedometer} steps
                  </Text>
                </HStack>
              </HStack>
            </VStack>
          </VStack>
        )}

        {!(deviceConnectionState === "connected") && (
          <Button
            action={"primary"}
            variant={"solid"}
            size={"lg"}
            isDisabled={deviceConnectionState === "connecting"}
            onPress={connectToDevice}
          >
            <ButtonText>Search for device</ButtonText>
            <Icon as={SearchIcon} size="lg" className="stroke-typography-100" />
          </Button>
        )}
      </VStack>
    </Card>
  );
};

export default BandStatus;
