import { View, Text } from "react-native";
import React from "react";
import Auth from "@/components/providers/Auth";
import { Slot } from "expo-router";

type Props = {};

const RootLayout = (props: Props) => {
  return <Slot />;
};

export default RootLayout;
