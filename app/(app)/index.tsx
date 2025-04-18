import BandStatus from "@/components/specific/BandStatus";
import EmergencyContacts from "@/components/specific/EmergencyContacts";
import RecieveData from "@/components/specific/RecieveData";
import RecordAudio from "@/components/specific/RecordAudio";
import Shield from "@/components/specific/Shield";
import { Avatar, AvatarImage } from "@/components/ui/avatar";
import { Center } from "@/components/ui/center";
import { HStack } from "@/components/ui/hstack";
import { Text } from "@/components/ui/text";
import { VStack } from "@/components/ui/vstack";
import { useAppStore } from "@/lib/app-store";
import { Link } from "expo-router";
import React from "react";
import { ScrollView } from "react-native";
import auth from "@react-native-firebase/auth";
import { UserIcon } from "lucide-react-native";
import { Icon } from "@/components/ui/icon";
import ContactsMap from "@/components/specific/ContactsMap";
import DebugPanel from "@/components/specific/DebugPanel";
import { Button, ButtonText } from "@/components/ui/button";
import { useDeviceActions } from "@/lib/useDeviceActions";

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
    <ScrollView className="flex-1 w-full">
      <HStack className="px-4 py-2 justify-end bg-background-0">
        <Link href="/profile">
          <Avatar size="lg" className="bg-background-0">
            {user && user.photoURL ? (
              <AvatarImage
                source={{
                  uri: user.photoURL,
                }}
              />
            ) : (
              <Icon as={UserIcon} className="stroke-typography-900 w-8 h-8" />
            )}
          </Avatar>
        </Link>
      </HStack>
      <VStack space="lg" className="flex-1 w-full py-10">
        <Shield />
        <Center>
          <BandStatus />
          <Button onPress={handleDemo} variant="outline">
            <ButtonText>
              {demo.isDemoActive ? "Stop Demo" : "Start Demo"}
            </ButtonText>
          </Button>
        </Center>

        {deviceConnectionState === "connected" && (
          <Center>
            <Text size="lg" className="text-typography-900">
              Friends and Family
            </Text>
          </Center>
        )}
        {/* <EmergencyContacts /> */}
        <ContactsMap />
        {/* <DebugPanel /> */}
        {/* <RecordAudio /> */}
      </VStack>
    </ScrollView>
  );
};
export default HomePage;
