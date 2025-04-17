import React from "react";
import { useDeviceActions } from "@/lib/useDeviceActions";
import { Button, ButtonText } from "../ui/button";
import { Box } from "../ui/box";
import { Text } from "../ui/text";

type Props = {};

const RecieveData = (props: Props) => {
  const { data } = useDeviceActions();
  return (
    <Box>
      <Text>RecieveData</Text>
      <Text>{data}</Text>
    </Box>
  );
};

export default RecieveData;
