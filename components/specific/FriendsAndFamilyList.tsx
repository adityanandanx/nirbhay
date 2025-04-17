import React from "react";
import { VStack } from "../ui/vstack";
import { UsersIcon, ArrowRightIcon } from "lucide-react-native";
import { Card } from "../ui/card";
import { Divider } from "../ui/divider";
import { HStack } from "../ui/hstack";
import { Text } from "../ui/text";
import { Icon } from "../ui/icon";
import { Box } from "../ui/box";

type Props = {};

const FriendsAndFamilyList = (props: Props) => {
  return (
    <VStack>
      {/* FAMILY */}
      <Card size="lg">
        <HStack space="2xl" className=" items-center">
          <Box className="p-2">
            <Icon as={UsersIcon} className="stroke-typography-900 w-12 h-12" />
          </Box>
          <VStack className="justify-center flex-1">
            <Text size="2xl" bold className="text-typography-900">
              Family
            </Text>
            <Text size="sm" className="text-typography-900">
              7 members
            </Text>
          </VStack>

          <Icon as={ArrowRightIcon} className="stroke-typography-500 w-8 h-8" />
        </HStack>
      </Card>
      <Divider />

      {/* FRIENDS */}
      <Card size="lg">
        <HStack space="2xl" className=" items-center">
          <Box className="p-2">
            <Icon as={UsersIcon} className="stroke-typography-900 w-12 h-12" />
          </Box>
          <VStack className="justify-center flex-1">
            <Text size="2xl" bold className="text-typography-900">
              Friends
            </Text>
            <Text size="sm" className="text-typography-900">
              30 people
            </Text>
          </VStack>

          <Icon as={ArrowRightIcon} className="stroke-typography-500 w-8 h-8" />
        </HStack>
      </Card>
      <Divider />
    </VStack>
  );
};

export default FriendsAndFamilyList;
