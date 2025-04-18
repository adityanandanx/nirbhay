import React from "react";
import { Phone, AlertCircle, ArrowLeft } from "lucide-react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import MapView, { Marker } from "react-native-maps";
import { Linking, Platform, View } from "react-native";
import { VStack } from "@/components/ui/vstack";
import { HStack } from "@/components/ui/hstack";
import { Button, ButtonText } from "@/components/ui/button";
import { Icon } from "@/components/ui/icon";
import { Text } from "@/components/ui/text";

export default function SOSDetails() {
  const router = useRouter();
  const params = useLocalSearchParams();

  // Extract params
  const latitude = parseFloat(params.latitude as string);
  const longitude = parseFloat(params.longitude as string);
  const senderName = params.senderName as string;
  const senderUid = params.senderUid as string;
  const timestamp = parseInt(params.timestamp as string);

  // Handle calling
  const callPerson = () => {
    // You might want to get the phone number from the database
    // For now, let's assume it's passed or we can get it from the user object
    const phoneNumber = params.phoneNumber as string;
    if (phoneNumber) {
      const phoneUrl =
        Platform.OS === "android"
          ? `tel:${phoneNumber}`
          : `telprompt:${phoneNumber}`;
      Linking.openURL(phoneUrl);
    }
  };

  // Check if coordinates are valid
  const hasValidCoordinates = !isNaN(latitude) && !isNaN(longitude);

  return (
    <View className="flex-1">
      <VStack className="flex-1">
        {/* Header */}
        <VStack className="bg-error-500 p-4">
          <HStack space="md" className="items-center">
            <Button
              variant="outline"
              onPress={() => router.back()}
              className="p-2"
            >
              <Icon as={ArrowLeft} className="stroke-white w-6 h-6" />
            </Button>
            <Text className="text-xl font-bold text-white">Emergency SOS</Text>
          </HStack>

          <VStack className="mt-4 mb-2 items-center">
            <Icon as={AlertCircle} className="stroke-white w-12 h-12 mb-2" />
            <Text className="text-white text-lg font-bold">
              {senderName || "Someone"} needs help!
            </Text>
            <Text className="text-white text-sm">
              Sent at {new Date(timestamp).toLocaleTimeString()}
            </Text>
          </VStack>
        </VStack>

        {/* Map */}
        {hasValidCoordinates ? (
          <MapView
            style={{ flex: 1 }}
            initialRegion={{
              latitude,
              longitude,
              latitudeDelta: 0.005,
              longitudeDelta: 0.005,
            }}
          >
            <Marker
              coordinate={{ latitude, longitude }}
              title={`${senderName}'s Location`}
              description={`Emergency alert sent at ${new Date(
                timestamp
              ).toLocaleTimeString()}`}
              pinColor="#DC2626"
            />
          </MapView>
        ) : (
          <View className="flex-1 items-center justify-center p-4">
            <Text className="text-center">
              Location information unavailable or invalid.
            </Text>
          </View>
        )}

        {/* Actions */}
        <VStack className="p-4 bg-white" space="md">
          <Button onPress={callPerson} className="bg-success-600">
            <HStack space="sm" className="items-center justify-center">
              <Icon as={Phone} className="stroke-white w-5 h-5" />
              <ButtonText>Call Now</ButtonText>
            </HStack>
          </Button>

          {hasValidCoordinates && (
            <Button
              onPress={() => {
                const scheme = Platform.select({
                  ios: "maps:",
                  android: "geo:",
                });
                const latLng = `${latitude},${longitude}`;
                const label = `${senderName}'s Emergency Location`;
                const url = Platform.select({
                  ios: `${scheme}?q=${label}&ll=${latLng}`,
                  android: `${scheme}${latLng}?q=${latLng}(${label})`,
                });

                if (url) {
                  Linking.openURL(url);
                }
              }}
              className="bg-primary-600"
            >
              <ButtonText>Open in Maps App</ButtonText>
            </Button>
          )}
        </VStack>
      </VStack>
    </View>
  );
}
