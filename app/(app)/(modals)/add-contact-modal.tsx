import {
  FormControl,
  FormControlHelper,
  FormControlHelperText,
  FormControlError,
  FormControlErrorIcon,
  FormControlErrorText,
} from "@/components/ui/form-control";
import { AlertCircleIcon } from "lucide-react-native";

import React from "react";
import auth from "@react-native-firebase/auth";
import { View } from "@/components/ui/view";
import { Text } from "@/components/ui/text";
import { VStack } from "@/components/ui/vstack";
import { Heading } from "@/components/ui/heading";
import { Input, InputField } from "@/components/ui/input";
import {
  FormControlLabel,
  FormControlLabelText,
} from "@/components/ui/form-control";
import { Button, ButtonText } from "@/components/ui/button";
import firestore from "@react-native-firebase/firestore";
import { useRouter } from "expo-router";

type Props = {};

const AddContact = (props: Props) => {
  const user = auth().currentUser;
  const router = useRouter();
  const [pending, setPending] = React.useState(false);
  const [error, setError] = React.useState(false);
  const [errorMessage, setErrorMessage] = React.useState("");
  const [contactName, setContactName] = React.useState("Mom");
  const [contactNumber, setContactNumber] = React.useState("+91 1234 567 891");

  const addContact = async () => {
    if (!user) {
      console.log("User not found");
      return;
    }
    setPending(true);
    try {
      await firestore()
        .collection("users")
        .doc(user.uid + "/contacts/" + contactNumber.replace(/\s/g, ""))
        .set({
          name: contactName,
          phoneNumber: contactNumber,
        });
    } catch (error) {
      console.log(error);
      setError(true);
      setErrorMessage("Failed to add contact");
      setPending(false);
      return;
    }
    setPending(false);
    router.back();
  };

  return (
    <VStack className="p-8" space="xl">
      <Heading size="3xl">Add Contact</Heading>
      <FormControl size={"md"} isRequired={true}>
        <FormControlLabel>
          <FormControlLabelText>Name</FormControlLabelText>
        </FormControlLabel>
        <Input>
          <InputField
            value={contactName}
            onChangeText={setContactName}
            type="text"
            defaultValue="John Doe"
            placeholder="Name"
          />
        </Input>

        <FormControlHelper>
          <FormControlHelperText>
            Enter the name of the contact you want to add.
          </FormControlHelperText>
        </FormControlHelper>

        <View className="my-2" />

        <FormControlLabel>
          <FormControlLabelText>Phone Number</FormControlLabelText>
        </FormControlLabel>
        <Input>
          <InputField
            value={contactNumber}
            onChangeText={setContactNumber}
            keyboardType="phone-pad"
            type="text"
            defaultValue="+91 1234 567 890"
            placeholder="Phone Number"
          />
        </Input>

        <FormControlHelper>
          <FormControlHelperText>
            Enter the phone number of the contact you want to add.
          </FormControlHelperText>
        </FormControlHelper>

        {error && (
          <FormControlError>
            <FormControlErrorIcon as={AlertCircleIcon} />
            <FormControlErrorText>{errorMessage}</FormControlErrorText>
          </FormControlError>
        )}

        <View className="my-2" />

        <Button
          onPress={addContact}
          disabled={pending}
          isDisabled={pending}
          className="w-full"
        >
          <ButtonText>Add Contact</ButtonText>
        </Button>
      </FormControl>
    </VStack>
  );
};
export default AddContact;
