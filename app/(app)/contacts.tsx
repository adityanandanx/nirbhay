import EmergencyContacts from "@/components/specific/EmergencyContacts";
import React from "react";
import { ScrollView } from "react-native";

type Props = {};

const Contacts = (props: Props) => {
  return (
    <ScrollView>
      <EmergencyContacts />
    </ScrollView>
  );
};

export default Contacts;
