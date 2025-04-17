import React, { useEffect, useState } from "react";
import {
  Modal,
  ModalBody,
  ModalContent,
  ModalFooter,
  ModalHeader,
} from "../ui/modal";
import { Text } from "../ui/text";
import { VStack } from "../ui/vstack";
import { HStack } from "../ui/hstack";
import { Button, ButtonText } from "../ui/button";
import { Icon } from "../ui/icon";
import { AlertCircle, MapPin, Phone } from "lucide-react-native";
import auth from "@react-native-firebase/auth";
import database from "@react-native-firebase/database";
import { Linking, Platform } from "react-native";
import { useRouter } from "expo-router";

type SOSNotification = {
  id: string;
  type: string;
  title: string;
  message: string;
  senderUid: string;
  senderName: string;
  sosReference: string;
  read: boolean;
  timestamp: number;
};

type SOSLocation = {
  latitude: number;
  longitude: number;
  timestamp: number;
  user: {
    displayName: string;
    phoneNumber: string;
  };
};

const SOSNotificationListener = () => {
  const [notification, setNotification] = useState<SOSNotification | null>(
    null
  );
  const [sosLocation, setSOSLocation] = useState<SOSLocation | null>(null);
  const [isModalOpen, setIsModalOpen] = useState<boolean>(false);
  const router = useRouter();
  const user = auth().currentUser;

  useEffect(() => {
    if (!user) return;

    // Listen for new notifications
    const notificationsRef = database().ref(`/notifications/${user.uid}`);
    notificationsRef
      .orderByChild("read")
      .equalTo(false)
      .limitToLast(1)
      .on("child_added", async (snapshot) => {
        const notifData = snapshot.val();
        const notifId = snapshot.key;

        if (notifData && notifData.type === "SOS" && !notifData.read) {
          // Get the SOS details
          try {
            const sosRef = database().ref(notifData.sosReference);
            const sosSnapshot = await sosRef.once("value");
            const sosData = sosSnapshot.val();

            if (sosData && sosData.active) {
              // Show the notification
              setNotification({
                id: notifId || "",
                ...notifData,
              });
              setSOSLocation(sosData);
              setIsModalOpen(true);

              // Mark as read
              await notificationsRef
                .child(notifId || "")
                .update({ read: true });
            }
          } catch (error) {
            console.error("Error fetching SOS details:", error);
          }
        }
      });

    return () => {
      notificationsRef.off("child_added");
    };
  }, [user?.uid]);

  const closeModal = () => {
    setIsModalOpen(false);
    setNotification(null);
    setSOSLocation(null);
  };

  const viewOnMap = () => {
    closeModal();

    if (sosLocation) {
      router.push({
        pathname: "/(app)/sos-details",
        params: {
          latitude: sosLocation.latitude,
          longitude: sosLocation.longitude,
          senderName: notification?.senderName || "",
          senderUid: notification?.senderUid || "",
          timestamp: sosLocation.timestamp,
        },
      });
    }
  };

  const callPerson = () => {
    if (sosLocation?.user?.phoneNumber) {
      const phoneNumber =
        Platform.OS === "android"
          ? `tel:${sosLocation.user.phoneNumber}`
          : `telprompt:${sosLocation.user.phoneNumber}`;
      Linking.openURL(phoneNumber);
    }
  };

  if (!isModalOpen || !notification || !sosLocation) {
    return null;
  }

  return (
    <Modal isOpen={isModalOpen} onClose={closeModal}>
      <ModalContent>
        <ModalBody>
          <VStack space="lg" className="items-center p-4">
            <Icon as={AlertCircle} className="stroke-danger-600 w-16 h-16" />
            <Text className="text-xl font-bold text-center text-error-600">
              {notification.title}
            </Text>
            <Text className="text-center">{notification.message}</Text>
            <Text className="text-center text-sm text-typography-500">
              Sent {new Date(sosLocation.timestamp).toLocaleTimeString()}
            </Text>
          </VStack>
        </ModalBody>
        <ModalFooter>
          <VStack space="md" className="w-full">
            <Button onPress={viewOnMap} className="w-full bg-primary-600">
              <HStack space="sm" className="items-center">
                <Icon as={MapPin} className="stroke-white w-5 h-5" />
                <ButtonText>View on Map</ButtonText>
              </HStack>
            </Button>
            {sosLocation.user?.phoneNumber && (
              <Button onPress={callPerson} className="w-full bg-success-600">
                <HStack space="sm" className="items-center">
                  <Icon as={Phone} className="stroke-white w-5 h-5" />
                  <ButtonText>Call Now</ButtonText>
                </HStack>
              </Button>
            )}
            <Button onPress={closeModal} className="w-full bg-background-200">
              <ButtonText className="text-typography-900">Dismiss</ButtonText>
            </Button>
          </VStack>
        </ModalFooter>
      </ModalContent>
    </Modal>
  );
};

export default SOSNotificationListener;
