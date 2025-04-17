import auth from "@react-native-firebase/auth";
import firestore from "@react-native-firebase/firestore";
import { Link } from "expo-router";
import { PhoneIcon, UserIcon, MapPinIcon } from "lucide-react-native";
import React, { useEffect, useState } from "react";
import {
  Alert,
  Linking,
  PermissionsAndroid,
  TouchableOpacity,
} from "react-native";
import { Avatar } from "../ui/avatar";
import { Button, ButtonText } from "../ui/button";
import { Card } from "../ui/card";
import { FlatList } from "../ui/flat-list";
import { HStack } from "../ui/hstack";
import { Icon } from "../ui/icon";
import { Spinner } from "../ui/spinner";
import { Text } from "../ui/text";
import { View } from "../ui/view";
import { VStack } from "../ui/vstack";
// @ts-ignore
import call from "react-native-phone-call";
import { useContactsLocations } from "../../lib/useContactsLocations";

type Contact = {
  name: string;
  phoneNumber: string;
};

type Props = {};

const EmergencyContacts = (props: Props) => {
  const [loading, setLoading] = useState(true); // Set loading to true on component mount
  const [contacts, setContacts] = useState<
    { name: string; phoneNumber: string }[]
  >([]); // Initial empty array of users
  const user = auth().currentUser;

  // Get location status of contacts
  const { contactsLocations } = useContactsLocations();

  useEffect(() => {
    if (!user) throw new Error("User not found");
    const subscriber = firestore()
      .collection(`users/${user.uid}/contacts`)
      .onSnapshot((querySnapshot) => {
        const contacts: { name: string; phoneNumber: string }[] = [];

        querySnapshot.forEach((contactNumber) => {
          contacts.push(contactNumber.data() as Contact);
        });

        setContacts(contacts);
        setLoading(false);
      });

    // Unsubscribe from events when no longer in use
    return () => subscriber();
  }, []);

  // Function to make a phone call
  const makePhoneCall = async (phoneNumber: string) => {
    await PermissionsAndroid.request(
      PermissionsAndroid.PERMISSIONS.CALL_PHONE,
      {
        title: "Phone Call Permission",
        message: "This app needs access to your phone to make calls.",
        buttonNeutral: "Ask Me Later",
        buttonNegative: "Cancel",
        buttonPositive: "OK",
      }
    );
    // Format the phone number for the dialer
    const formattedNumber = phoneNumber.replace(/\s/g, "").replace("+", "");
    console.log(formattedNumber);

    await call({
      number: formattedNumber, // String value with the number to call
      prompt: false, // Optional boolean property. Determines if the user should be prompted prior to the call
      skipCanOpen: true, // Skip the canOpenURL check
    });
  };

  // Helper function to check if location is recent (within the last 5 minutes)
  const isLocationRecent = (timestamp: number) => {
    if (!timestamp) return false;
    const fiveMinutesAgo = Date.now() - 5 * 60 * 1000;
    return timestamp > fiveMinutesAgo;
  };

  // Find location status for a contact
  const getLocationStatus = (phoneNumber: string) => {
    const contactWithLocation = contactsLocations.find(
      (c) => c.phoneNumber.replace(/\s/g, "") === phoneNumber.replace(/\s/g, "")
    );

    if (!contactWithLocation || !contactWithLocation.location) {
      return { hasLocation: false };
    }

    return {
      hasLocation: true,
      isRecent: isLocationRecent(contactWithLocation.location.timestamp),
      timestamp: contactWithLocation.location.timestamp,
    };
  };

  if (loading) return <Spinner />;

  return (
    <FlatList
      scrollEnabled={false}
      data={contacts}
      renderItem={({ item }) => {
        const locationStatus = getLocationStatus(item.phoneNumber);

        return (
          <Card size="lg">
            <HStack className="items-center justify-between" space="2xl">
              <Link
                href={{
                  pathname: "/(app)/edit-contact-modal",
                  params: {
                    contactId: item.phoneNumber.replace(/\s/g, ""),
                    originalName: item.name,
                    originalNumber: item.phoneNumber,
                  },
                }}
                asChild
              >
                <TouchableOpacity className="flex-1">
                  <HStack className="items-center" space="2xl">
                    <Avatar
                      size="lg"
                      className="border border-background-100 bg-background-0"
                    >
                      <Icon
                        as={UserIcon}
                        className="stroke-typography-900 w-8 h-8"
                      />
                    </Avatar>
                    <VStack>
                      <HStack space="sm" className="items-center">
                        <Text size="xl">{item.name}</Text>
                        {locationStatus.hasLocation && (
                          <Icon
                            as={MapPinIcon}
                            className={`w-4 h-4 ${
                              locationStatus.isRecent
                                ? "stroke-success-500"
                                : "stroke-warning-500"
                            }`}
                          />
                        )}
                      </HStack>
                      <Text size="sm">{item.phoneNumber}</Text>
                      {locationStatus.hasLocation && (
                        <Text size="xs" className="text-typography-500">
                          Last seen:{" "}
                          {locationStatus.timestamp
                            ? new Date(
                                locationStatus.timestamp
                              ).toLocaleTimeString()
                            : null}
                        </Text>
                      )}
                    </VStack>
                  </HStack>
                </TouchableOpacity>
              </Link>
              <HStack space="md">
                <TouchableOpacity
                  onPress={() => makePhoneCall(item.phoneNumber)}
                  className="rounded-full p-3"
                >
                  <Icon as={PhoneIcon} className="stroke-white w-5 h-5" />
                </TouchableOpacity>
              </HStack>
            </HStack>
          </Card>
        );
      }}
      ListFooterComponent={() => (
        <View className="p-8">
          <Link asChild href={"/(app)/add-contact-modal"}>
            <Button>
              <ButtonText>Add Contact</ButtonText>
            </Button>
          </Link>
        </View>
      )}
    />
  );
};

export default EmergencyContacts;
