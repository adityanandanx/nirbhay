import { Box } from "@/components/ui/box";
import { Button, ButtonText } from "@/components/ui/button";
import {
  FormControl,
  FormControlHelper,
  FormControlHelperText,
  FormControlLabel,
  FormControlLabelText,
} from "@/components/ui/form-control";
import { Heading } from "@/components/ui/heading";
import { ImageBackground } from "@/components/ui/image-background";
import { Input, InputField } from "@/components/ui/input";
import { VStack } from "@/components/ui/vstack";
import auth, { FirebaseAuthTypes } from "@react-native-firebase/auth";
import { useRouter } from "expo-router";
import React, { useState } from "react";

type Props = {};
const SignIn = (props: Props) => {
  const [phoneNumber, setPhoneNumber] = useState("+91 1234 567 890");
  const [result, setResult] =
    useState<FirebaseAuthTypes.ConfirmationResult | null>(null);
  const [otp, setOtp] = useState("111111");
  const [pending, setPending] = useState(false);

  const router = useRouter();

  const handleSubmit = async () => {
    setPending(true);
    const res = await auth().signInWithPhoneNumber(phoneNumber);
    console.log("Sign in id", res.verificationId);

    setResult(res);
    setPending(false);
  };

  const handleOtpSubmit = async () => {
    setPending(true);
    if (result) {
      try {
        const user = await result.confirm(otp);
        console.log(user);
        // User signed in successfully
      } catch (error) {
        // Handle error
        console.log(error);
      }
    }
    setPending(true);
    router.replace("/");
  };

  return (
    <VStack space="lg" className="flex-1">
      <ImageBackground
        className="flex-1 object-contain"
        source={require("@/assets/images/woman.jpeg")}
      />

      <VStack className="p-8 w-full rounded-md">
        <Heading size="5xl">Sign In</Heading>
        <FormControl
          // isInvalid={isInvalid}
          size="md"
          isDisabled={result ? false : pending}
          isReadOnly={result ? false : pending}
          isRequired={true}
        >
          {/* Phone Number */}
          <FormControlLabel>
            <FormControlLabelText>Phone Number</FormControlLabelText>
          </FormControlLabel>
          <Input isDisabled={false} isReadOnly={false}>
            <InputField
              placeholder="+91 12345 67890"
              value={phoneNumber}
              onChangeText={setPhoneNumber}
            />
          </Input>
          <FormControlHelper>
            <FormControlHelperText>
              You will recieve an OTP on this number
            </FormControlHelperText>
          </FormControlHelper>

          <Box className="my-3" />

          {result && (
            <>
              <FormControlLabel>
                <FormControlLabelText>OTP</FormControlLabelText>
              </FormControlLabel>
              <Input>
                <InputField
                  placeholder="123456"
                  value={otp}
                  onChangeText={setOtp}
                />
              </Input>
              <FormControlHelper>
                <FormControlHelperText>
                  Enter your 6 digit OTP sent to your phone number
                </FormControlHelperText>
              </FormControlHelper>
            </>
          )}
        </FormControl>
        {result ? (
          <Button
            disabled={pending}
            isDisabled={pending}
            className="w-fit self-end mt-4"
            onPress={handleOtpSubmit}
          >
            <ButtonText>Verify</ButtonText>
          </Button>
        ) : (
          <Button
            disabled={pending}
            isDisabled={pending}
            className="w-fit self-end mt-4"
            onPress={handleSubmit}
          >
            <ButtonText>Sign in</ButtonText>
          </Button>
        )}
      </VStack>
    </VStack>
  );
};
export default SignIn;
