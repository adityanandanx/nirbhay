import { ArrowRightIcon, UserIcon, UsersIcon } from "lucide-react-native";
import React, { useEffect, useState } from "react";
import { Box } from "../ui/box";
import { Card } from "../ui/card";
import { Divider } from "../ui/divider";
import { HStack } from "../ui/hstack";
import { Icon } from "../ui/icon";
import { Text } from "../ui/text";
import { VStack } from "../ui/vstack";
import { Spinner } from "../ui/spinner";
import firestore from "@react-native-firebase/firestore";
import { FirebaseAuthTypes } from "@react-native-firebase/auth";
import { FlatList } from "../ui/flat-list";
import { View } from "../ui/view";
import { Avatar, AvatarImage } from "../ui/avatar";
import auth from "@react-native-firebase/auth";
import { Button, ButtonText } from "../ui/button";
import { Link } from "expo-router";

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

  useEffect(() => {
    if (!user) throw new Error("User not found");
    const subscriber = firestore()
      .collection(`users/${user.uid}/contacts`)
      // .doc(user.uid + "/contacts/")
      .onSnapshot((querySnapshot) => {
        const contacts: { name: string; phoneNumber: string }[] = [];

        querySnapshot.forEach((contactNumber) => {
          contacts.push(contactNumber.data() as Contact);

          // firestore()
          //   .collection("users")
          //   .doc(contact)
          //   .get()
          //   .then((doc) => {
          //     if (doc.exists) {
          //       contacts.push({
          //         name: doc.data()!.name,
          //         phoneNumber: doc.data()!.phoneNumber,
          //       });
          //     }
          //   });
          // firestore()
          //   .collection("users")
          //   .where("phoneNumber", "==", contact.phoneNumber)
          //   .get()
          //   .then((doc) => {
          //     if (doc.empty) {
          //       console.log("No such document!");
          //       return;
          //     }
          //     doc.forEach((doc) => {
          //       contacts.push({
          //         name: doc.data().name,
          //         phoneNumber: doc.data().phoneNumber,
          //       });
          //     });
          //   });
          // contacts.push(contact);
        });

        setContacts(contacts);
        setLoading(false);
      });

    // Unsubscribe from events when no longer in use
    return () => subscriber();
  }, []);

  if (loading) return <Spinner />;

  return (
    <FlatList
      scrollEnabled={false}
      data={contacts}
      renderItem={({ item }) => (
        <Card size="lg">
          <HStack className="items-center" space="2xl">
            <Avatar
              size="lg"
              className="border border-background-100 bg-background-0"
            >
              <Icon as={UserIcon} className="stroke-typography-900 w-8 h-8" />
            </Avatar>
            <VStack>
              <Text size="xl">{item.name}</Text>
              <Text size="sm">{item.phoneNumber}</Text>
            </VStack>
          </HStack>
        </Card>
      )}
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
