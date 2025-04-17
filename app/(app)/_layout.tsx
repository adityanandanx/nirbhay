import { Link, Redirect, Stack } from "expo-router";
import React from "react";

import auth from "@react-native-firebase/auth";
import { Avatar, AvatarImage } from "@/components/ui/avatar";
import { Pressable } from "@/components/ui/pressable";
import { Icon } from "@/components/ui/icon";
import { PersonStandingIcon, User2Icon, UserIcon } from "lucide-react-native";
import { Text } from "@/components/ui/text";
import { View } from "react-native";
import { VStack } from "@/components/ui/vstack";
import { HStack } from "@/components/ui/hstack";

export {
  // Catch any errors thrown by the Layout component.
  ErrorBoundary,
} from "expo-router";

export default function RootLayoutNav() {
  const user = auth().currentUser;

  if (!user) return <Redirect href={"/sign-in"} />;

  return (
    <VStack className="flex-1">
      <Stack
        screenOptions={{
          headerShown: false,
        }}
      >
        <Stack.Screen name="index" />
        <Stack.Screen name="profile" />
      </Stack>
    </VStack>
  );
}
