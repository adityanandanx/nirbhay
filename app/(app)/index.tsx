import BandStatus from "@/components/specific/BandStatus";
import Shield from "@/components/specific/Shield";
import { Button, ButtonText } from "@/components/ui/button";
import { Center } from "@/components/ui/center";
import { VStack } from "@/components/ui/vstack";
import { useAppStore } from "@/lib/app-store";
import { useDeviceActions } from "@/lib/useDeviceActions";
import auth from "@react-native-firebase/auth";
import React from "react";
import { View } from "react-native";

type Props = {};

const HomePage = (props: Props) => {
  const deviceConnectionState = useAppStore(
    (state) => state.deviceConnectionState
  );
  const user = auth().currentUser;
  const { demo } = useDeviceActions();

  const handleDemo = () => {
    if (demo.isDemoActive) {
      demo.stopDemo();
    } else {
      demo.startDemo();
    }
  };
  return (
    <View className="flex-1 w-full">
      <VStack
        space="lg"
        className="flex-1 w-full py-10 justify-center items-center"
      >
        <Shield />
        <Center>
          <BandStatus />
          <Button onPress={handleDemo} variant="outline">
            <ButtonText>
              {demo.isDemoActive ? "Stop Demo" : "Start Demo"}
            </ButtonText>
          </Button>
        </Center>
      </VStack>
    </View>
  );
};
export default HomePage;
