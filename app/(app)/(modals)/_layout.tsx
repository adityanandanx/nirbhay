import { View, Text } from "react-native";
import React from "react";
import { Stack } from "expo-router";

type Props = {};

const Modals = (props: Props) => {
  return (
    <Stack>
      <Stack.Screen name="add-contact-modal" />
      <Stack.Screen name="edit-contact-modal" />
      <Stack.Screen name="sos-details" />
    </Stack>
  );
};

export default Modals;
