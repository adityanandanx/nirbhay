import BandStatus from "@/components/specific/BandStatus";
import EmergencyContacts from "@/components/specific/EmergencyContacts";
import RecieveData from "@/components/specific/RecieveData";
import RecordAudio from "@/components/specific/RecordAudio";
import Shield from "@/components/specific/Shield";
import { Center } from "@/components/ui/center";
import { Text } from "@/components/ui/text";
import { VStack } from "@/components/ui/vstack";
import { useAppStore } from "@/lib/app-store";
import React from "react";
import { ScrollView } from "react-native";

type Props = {};

const HomePage = (props: Props) => {
  const deviceConnectionState = useAppStore(
    (state) => state.deviceConnectionState
  );
  return (
    <ScrollView className="flex-1 w-full">
      <VStack space="lg" className="flex-1 w-full py-10">
        <Shield />
        <Center>
          <BandStatus />
        </Center>
        {deviceConnectionState === "connected" && (
          <Center>
            <Text size="lg" className="text-typography-900">
              Friends and Family
            </Text>
          </Center>
        )}
        <EmergencyContacts />
        {/* <RecordAudio /> */}
      </VStack>
    </ScrollView>
  );
};
export default HomePage;
