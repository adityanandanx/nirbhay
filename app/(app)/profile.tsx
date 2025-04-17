import { Button, ButtonText } from "@/components/ui/button";
import { Text } from "@/components/ui/text";
import { VStack } from "@/components/ui/vstack";
import React from "react";
import auth from "@react-native-firebase/auth";
import { useRouter } from "expo-router";

type Props = {};

const Profile = (props: Props) => {
  const [pending, setIsPending] = React.useState(false);
  const router = useRouter();

  const logout = async () => {
    setIsPending(true);
    console.log("Signing out");
    await auth().signOut();
    setIsPending(false);
    router.replace("/sign-in");
  };

  return (
    <VStack className="p-8">
      <Text>Profile</Text>
      <Button
        onPress={() => logout()}
        disabled={pending}
        isDisabled={pending}
        className="w-full"
      >
        <ButtonText>Logout</ButtonText>
      </Button>
    </VStack>
  );
};

export default Profile;
