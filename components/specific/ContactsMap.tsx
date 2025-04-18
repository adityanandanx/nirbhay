import React, { useState } from "react";
import { View } from "../ui/view";
import { Text } from "../ui/text";
import MapView, { Marker, Callout } from "react-native-maps";
import { useContactsLocations } from "../../lib/useContactsLocations";
import { Spinner } from "../ui/spinner";
import { VStack } from "../ui/vstack";
import { UserIcon, AlertTriangle, AlertCircle } from "lucide-react-native";
import { Icon } from "../ui/icon";
import LocationDebug from "./LocationDebug";
import { HStack } from "../ui/hstack";
import {
  Modal,
  ModalBody,
  ModalContent,
  ModalFooter,
  ModalHeader,
} from "../ui/modal";
import { ActivityIndicator } from "react-native";
import { Button, ButtonText } from "../ui/button";
import { useSendSOS } from "../../lib/useSendSOS";

type Props = {};

const ContactsMap = (props: Props) => {
  const { myLocation, contactsLocations, loading, errorMsg } =
    useContactsLocations();
  const [sosModalVisible, setSosModalVisible] = useState(false);
  const { sendSOS, isLoading: isSending, result } = useSendSOS();

  // Handle SOS button press
  const handleSOSPress = () => {
    setSosModalVisible(true);
  };

  // Confirm and send SOS
  const confirmSendSOS = async () => {
    await sendSOS();
    // Keep modal open to show result
  };

  // Close modal and reset state
  const closeModal = () => {
    setSosModalVisible(false);
  };

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
      {/* SOS Button at the top */}
      <Button
        onPress={handleSOSPress}
        className="bg-error-500 w-fit self-center px-6 py-3"
      >
        {/* <HStack space="md" className="items-center"> */}
        <Icon as={AlertCircle} className="stroke-white w-5 h-5" />
        <ButtonText className="font-bold">SOS</ButtonText>
        {/* </HStack> */}
      </Button>

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
      {/* <LocationDebug /> */}

      {/* SOS Confirmation Modal */}
      <Modal isOpen={sosModalVisible} onClose={closeModal}>
        <ModalContent>
          <ModalHeader>
            <Text className="text-xl font-bold text-center">Emergency SOS</Text>
          </ModalHeader>
          <ModalBody>
            {isSending ? (
              <VStack space="md" className="items-center p-4">
                <ActivityIndicator size="large" color="#DC2626" />
                <Text>Sending SOS to your emergency contacts...</Text>
              </VStack>
            ) : result ? (
              <VStack space="md" className="items-center p-4">
                {result.success ? (
                  <>
                    <Icon
                      as={AlertCircle}
                      className="stroke-success-500 w-12 h-12"
                    />
                    <Text className="text-center">
                      Emergency alert sent to {result.sentCount} contacts
                    </Text>
                  </>
                ) : (
                  <>
                    <Icon
                      as={AlertTriangle}
                      className="stroke-danger-500 w-12 h-12"
                    />
                    <Text className="text-center">
                      {result.error || "Failed to send emergency alert"}
                    </Text>
                  </>
                )}
              </VStack>
            ) : (
              <VStack space="lg" className="items-center p-4">
                <Icon
                  as={AlertCircle}
                  className="stroke-danger-500 w-16 h-16"
                />
                <Text className="text-center text-lg">
                  This will send an emergency alert with your current location
                  to all your emergency contacts.
                </Text>
                <Text className="text-center font-bold">
                  Are you sure you want to continue?
                </Text>
              </VStack>
            )}
          </ModalBody>
          <ModalFooter>
            {!isSending && !result ? (
              <HStack className="w-full justify-between">
                <Button
                  onPress={closeModal}
                  className="flex-1 mr-2 bg-background-200"
                >
                  <ButtonText className="text-typography-900">
                    Cancel
                  </ButtonText>
                </Button>
                <Button
                  onPress={confirmSendSOS}
                  className="flex-1 ml-2 bg-error-500"
                >
                  <ButtonText>Send SOS</ButtonText>
                </Button>
              </HStack>
            ) : result ? (
              <Button onPress={closeModal} className="w-full">
                <ButtonText>Close</ButtonText>
              </Button>
            ) : null}
          </ModalFooter>
        </ModalContent>
      </Modal>
    </View>
  );
};

export default ContactsMap;
