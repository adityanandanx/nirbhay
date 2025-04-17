import { Heading } from "@/components/ui/heading";
import { Text } from "@/components/ui/text";
import { VStack } from "@/components/ui/vstack";
import React from "react";

type Props = {};

const SignIn = (props: Props) => {
  return (
    <VStack>
      <Heading>Sign In</Heading>
      <Text>Phone number</Text>
    </VStack>
  );
};

export default SignIn;
