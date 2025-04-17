import React from "react";
import { View } from "../ui/view";
import { Text } from "../ui/text";
import MapView, { Marker, Callout } from "react-native-maps";
import { useContactsLocations } from "../../lib/useContactsLocations";
import { Spinner } from "../ui/spinner";
import { VStack } from "../ui/vstack";
import { UserIcon, AlertTriangle } from "lucide-react-native";
import { Icon } from "../ui/icon";
import LocationDebug from "./LocationDebug";

type Props = {};

const ContactsMap = (props: Props) => {
  const { myLocation, contactsLocations, loading, errorMsg } =
    useContactsLocations();

  if (loading) {
    return (
      <View className="flex-1 h-96 w-full items-center justify-center">
        <Spinner />
      </View>
    );
  }

  if (errorMsg) {
    return (
      <View className="flex-1 h-96 w-full items-center justify-center">
        <VStack space="md" className="items-center">
          <Icon as={AlertTriangle} className="stroke-danger-500 w-8 h-8" />
          <Text className="text-danger-500">{errorMsg}</Text>
        </VStack>
      </View>
    );
  }

  // Log to debug
  console.log("My location:", myLocation?.coords);
  console.log(
    "Contacts with locations:",
    contactsLocations.filter((c) => c.location)
  );

  return (
    <View className="flex-1 w-full">
      <MapView
        style={{ flex: 1, height: 512 }}
        showsMyLocationButton={true}
        showsUserLocation={true}
        showsTraffic={true}
        showsBuildings={true}
        showsCompass={true}
        showsScale={true}
        showsPointsOfInterest={true}
        followsUserLocation={true}
        initialRegion={{
          latitude: myLocation?.coords.latitude || 28.7041,
          longitude: myLocation?.coords.longitude || 77.1025,
          latitudeDelta: 0.0922,
          longitudeDelta: 0.0421,
        }}
      >
        {contactsLocations.map((contact) =>
          contact.location ? (
            <Marker
              key={contact.id}
              coordinate={{
                latitude: contact.location.latitude,
                longitude: contact.location.longitude,
              }}
              pinColor="#4CAF50"
              title={contact.name}
            >
              <Callout>
                <VStack space="sm" className="p-1">
                  <Text className="font-bold">{contact.name}</Text>
                  <Text>{contact.phoneNumber}</Text>
                  <Text className="text-xs text-typography-500">
                    Updated:{" "}
                    {new Date(contact.location.timestamp).toLocaleTimeString()}
                  </Text>
                </VStack>
              </Callout>
            </Marker>
          ) : null
        )}
      </MapView>

      {/* Add the debug component at the bottom */}
      <LocationDebug />
    </View>
  );
};

export default ContactsMap;
