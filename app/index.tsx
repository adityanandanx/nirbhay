import BandStatus from "@/components/specific/BandStatus";
import FriendsAndFamilyList from "@/components/specific/FriendsAndFamilyList";
import Shield from "@/components/specific/Shield";
import { Center } from "@/components/ui/center";
import { VStack } from "@/components/ui/vstack";
import React from "react";
import { ScrollView } from "react-native";

type Props = {};

const HomePage = (props: Props) => {
  return (
    <ScrollView className="flex-1 w-full">
      <VStack space="lg" className="flex-1 w-full py-10">
        <Shield />
        <Center>
          <BandStatus />
        </Center>
        <FriendsAndFamilyList />
      </VStack>
    </ScrollView>
  );
};
export default HomePage;
