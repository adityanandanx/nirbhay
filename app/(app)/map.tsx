import { View, Text } from "react-native";
import React from "react";
import ContactsMap from "@/components/specific/ContactsMap";

type Props = {};

const Map = (props: Props) => {
  return (
    <View className="flex-1">
      <ContactsMap />
    </View>
  );
};

export default Map;
