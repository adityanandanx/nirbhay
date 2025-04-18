import { Button, ButtonText } from "@/components/ui/button";
import { Card } from "../ui/card";
import { Text } from "../ui/text";
import { VStack } from "../ui/vstack";
import { useDeviceActions } from "@/lib/useDeviceActions";
import { useState } from "react";
import { TextInput } from "react-native";

const DebugPanel = () => {
  const { rawData, lastError, testParse } = useDeviceActions();
  const [testData, setTestData] = useState(
    "0.01,0.02,0.03,0.04,0.05,0.06,0.07,0.08,0.09,0.10,0.11,0.12,0.13,0.14,0.15,0.16,0.17,0.18,75,36.5,100,200,1.2,5.0,50,0.5"
  );
  const [parseResult, setParseResult] = useState<boolean | null>(null);

  const handleTestParse = () => {
    const result = testParse(testData);
    setParseResult(result);
  };

  return (
    <Card size="lg" className="mt-4">
      <VStack space="md" className="w-full">
        <Text bold size="lg">
          Debug Panel
        </Text>

        <VStack space="sm">
          <Text>Last Raw Data:</Text>
          <Text className="bg-gray-100 p-2 rounded">{rawData || "None"}</Text>
        </VStack>

        {lastError && <Text className="text-error-500">{lastError}</Text>}

        <Text>Test Parse:</Text>
        <TextInput
          value={testData}
          onChangeText={setTestData}
          multiline
          className="border border-gray-300 p-2 rounded text-typography-900"
          style={{ minHeight: 80 }}
        />

        <Button onPress={handleTestParse}>
          <ButtonText>Test Parse</ButtonText>
        </Button>

        {parseResult !== null && (
          <Text className={parseResult ? "text-success-500" : "text-error-500"}>
            {parseResult ? "Parse successful!" : "Parse failed!"}
          </Text>
        )}
      </VStack>
    </Card>
  );
};

export default DebugPanel;
