import {
  FormControl,
  FormControlHelper,
  FormControlHelperText,
  FormControlError,
  FormControlErrorIcon,
  FormControlErrorText,
  FormControlLabel,
  FormControlLabelText,
} from "@/components/ui/form-control";
import { AlertCircleIcon } from "lucide-react-native";

import React, { useEffect } from "react";
import auth from "@react-native-firebase/auth";
import { View } from "@/components/ui/view";
import { Text } from "@/components/ui/text";
import { VStack } from "@/components/ui/vstack";
import { Heading } from "@/components/ui/heading";
import { Input, InputField } from "@/components/ui/input";
import { Button, ButtonText } from "@/components/ui/button";
import firestore from "@react-native-firebase/firestore";
import { useLocalSearchParams, useRouter } from "expo-router";
import { Spinner } from "@/components/ui/spinner";

type Props = {};

const EditContact = (props: Props) => {
  const { contactId, originalName, originalNumber } = useLocalSearchParams<{
    contactId: string;
    originalName: string;
    originalNumber: string;
  }>();

  const user = auth().currentUser;
  const router = useRouter();
  const [pending, setPending] = React.useState(false);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState(false);
  const [errorMessage, setErrorMessage] = React.useState("");
  const [contactName, setContactName] = React.useState("");
  const [contactNumber, setContactNumber] = React.useState("");

  useEffect(() => {
    if (originalName && originalNumber) {
      setContactName(originalName);
      setContactNumber(originalNumber);
      setLoading(false);
    } else if (contactId && user) {
      // Fetch contact details if not passed as params
      firestore()
        .collection(`users/${user.uid}/contacts`)
        .doc(contactId)
        .get()
        .then((doc) => {
          if (doc.exists) {
            const data = doc.data();
            setContactName(data?.name || "");
            setContactNumber(data?.phoneNumber || "");
          } else {
            setError(true);
            setErrorMessage("Contact not found");
          }
          setLoading(false);
        })
        .catch((error) => {
          console.log("Error fetching contact:", error);
          setError(true);
          setErrorMessage("Failed to load contact");
          setLoading(false);
        });
    } else {
      setError(true);
      setErrorMessage("Invalid contact information");
      setLoading(false);
    }
  }, [contactId, originalName, originalNumber, user]);

  const updateContact = async () => {
    if (!user) {
      console.log("User not found");
      return;
    }
    setPending(true);

    try {
      const formattedNumber = contactNumber.replace(/\s/g, "");
      const originalFormattedNumber = originalNumber
        ? originalNumber.replace(/\s/g, "")
        : contactId;

      // If phone number changed, delete old document and create new one
      if (formattedNumber !== originalFormattedNumber) {
        // Create a batch to perform multiple operations atomically
        const batch = firestore().batch();

        // Delete the old document
        const oldContactRef = firestore()
          .collection(`users/${user.uid}/contacts`)
          .doc(originalFormattedNumber);

        // Create the new document
        const newContactRef = firestore()
          .collection(`users/${user.uid}/contacts`)
          .doc(formattedNumber);

        batch.delete(oldContactRef);
        batch.set(newContactRef, {
          name: contactName,
          phoneNumber: contactNumber,
        });

        // Commit the batch
        await batch.commit();
      } else {
        // Just update the existing document
        await firestore()
          .collection(`users/${user.uid}/contacts`)
          .doc(formattedNumber)
          .update({
            name: contactName,
            phoneNumber: contactNumber,
          });
      }

      setPending(false);
      router.back();
    } catch (error) {
      console.log("Error updating contact:", error);
      setError(true);
      setErrorMessage("Failed to update contact");
      setPending(false);
    }
  };

  if (loading) return <Spinner />;

  return (
    <VStack className="p-8" space="xl">
      <Heading size="3xl">Edit Contact</Heading>
      <FormControl size={"md"} isRequired={true}>
        <FormControlLabel>
          <FormControlLabelText>Name</FormControlLabelText>
        </FormControlLabel>
        <Input>
          <InputField
            value={contactName}
            onChangeText={setContactName}
            type="text"
            placeholder="Name"
          />
        </Input>

        <FormControlHelper>
          <FormControlHelperText>
            Edit the name of the contact.
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
            placeholder="Phone Number"
          />
        </Input>

        <FormControlHelper>
          <FormControlHelperText>
            Edit the phone number of the contact.
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
          onPress={updateContact}
          disabled={pending}
          isDisabled={pending}
          className="w-full"
        >
          <ButtonText>Update Contact</ButtonText>
        </Button>
      </FormControl>
    </VStack>
  );
};

export default EditContact;
