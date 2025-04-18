import { Link, Redirect, Stack, Tabs } from "expo-router";
import React from "react";

import auth from "@react-native-firebase/auth";
import { Avatar, AvatarImage } from "@/components/ui/avatar";
import { Pressable } from "@/components/ui/pressable";
import { Icon } from "@/components/ui/icon";
import {
  HomeIcon,
  MapIcon,
  PersonStandingIcon,
  User2Icon,
  UserIcon,
  UsersIcon,
} from "lucide-react-native";
import { Text } from "@/components/ui/text";
import { View } from "react-native";
import { VStack } from "@/components/ui/vstack";
import { HStack } from "@/components/ui/hstack";
import SOSNotificationListener from "../../components/specific/SOSNotificationListener";

export {
  // Catch any errors thrown by the Layout component.
  ErrorBoundary,
} from "expo-router";

export default function RootLayoutNav() {
  const user = auth().currentUser;

  if (!user) return <Redirect href={"/sign-in"} />;

  return (
    <>
      <VStack className="flex-1">
        <Tabs screenOptions={{ headerShown: false }}>
          <Tabs.Screen
            name="index"
            options={{
              tabBarIcon: () => (
                <Icon as={HomeIcon} className="stroke-typography-400" />
              ),
            }}
          />
          <Tabs.Screen
            name="contacts"
            options={{
              tabBarIcon: () => (
                <Icon as={UsersIcon} className="stroke-typography-400" />
              ),
            }}
          />
          <Tabs.Screen
            name="map"
            options={{
              tabBarIcon: () => (
                <Icon as={MapIcon} className="stroke-typography-400" />
              ),
            }}
          />
          <Tabs.Screen
            name="profile"
            options={{
              tabBarIcon: () => (
                <Icon as={User2Icon} className="stroke-typography-400" />
              ),
            }}
          />
          <Tabs.Screen name="(modals)" options={{ href: null }} />
        </Tabs>

        {/* <Stack
          screenOptions={{
            headerShown: false,
          }}
        >
          <Stack.Screen
            name="add-contact-modal"
            options={{ presentation: "modal" }}
          />
          <Stack.Screen
            name="edit-contact-modal"
            options={{ presentation: "modal" }}
          />
        </Stack> */}
      </VStack>
      <SOSNotificationListener />
    </>
  );
}
