import { TriangleAlertIcon } from "lucide-react-native";
import React, { useCallback, useState } from "react";
import { TouchableOpacity, View } from "react-native";
import { Box } from "../ui/box";
import { HStack } from "../ui/hstack";
import { Icon } from "../ui/icon";
import { Text } from "../ui/text";
import { Toast, ToastTitle, useToast } from "../ui/toast";
import { VStack } from "../ui/vstack";
import { Image } from "expo-image";

type Props = {};

const Shield = (props: Props) => {
  const [shieldState, setSheildState] = useState("standby");

  const toggleShield = () => {
    setSheildState((v) => (v === "standby" ? "active" : "standby"));
  };

  const toast = useToast();

  const handlePress = () => {
    if (shieldState === "inactive") {
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
        <Box className="w-80 h-80">
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
      </VStack>
    </TouchableOpacity>
  );
};

export default Shield;
