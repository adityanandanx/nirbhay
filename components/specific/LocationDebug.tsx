import React, { useEffect, useState } from "react";
import { ScrollView } from "react-native";
import { Text } from "../ui/text";
import { View } from "../ui/view";
import { Button, ButtonText } from "../ui/button";
import database from "@react-native-firebase/database";
import auth from "@react-native-firebase/auth";

type Props = {};

const LocationDebug = (props: Props) => {
  const [locationData, setLocationData] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const user = auth().currentUser;

  const refreshData = async () => {
    try {
      if (!user) {
        setError("No authenticated user");
        return;
      }

      // Get all location data
      const snapshot = await database().ref("/locations").once("value");
      const data = snapshot.val();
      setLocationData(data);
      console.log("DEBUG - Location data retrieved:", data);

      // Check if the current user's location exists
      const myLocationSnapshot = await database()
        .ref(`/locations/${user.uid}`)
        .once("value");
      const myLocation = myLocationSnapshot.val();
      console.log("DEBUG - My location data:", myLocation);
    } catch (err: any) {
      console.error("DEBUG - Error fetching location data:", err);
      setError(err.message);
    }
  };

  // Fetch data on mount
  useEffect(() => {
    refreshData();

    // Set up a listener for location updates
    if (user) {
      const locationsRef = database().ref("/locations");
      locationsRef.on("value", (snapshot) => {
        console.log("DEBUG - Location data updated:", snapshot.val());
        setLocationData(snapshot.val());
      });

      return () => locationsRef.off("value");
    }
  }, []);

  // Test function to manually update location
  const testUpdateLocation = async () => {
    if (!user) return;

    try {
      console.log("DEBUG - Manually updating location");
      await database()
        .ref(`/locations/${user.uid}`)
        .update({
          latitude: 28.7041 + Math.random() * 0.01,
          longitude: 77.1025 + Math.random() * 0.01,
          timestamp: database.ServerValue.TIMESTAMP,
          phoneNumber: user.phoneNumber || "",
          displayName: user.displayName || "",
          email: user.email || "",
        });
      console.log("DEBUG - Location manually updated");

      refreshData();
    } catch (err: any) {
      console.error("DEBUG - Error updating location:", err);
      setError(err.message);
    }
  };

  return (
    <View className="p-4 bg-background-100 rounded-lg my-4">
      <Text className="text-lg font-bold mb-2">Location Debug Info</Text>

      {error && (
        <View className="p-2 bg-danger-100 rounded mb-2">
          <Text className="text-danger-600">{error}</Text>
        </View>
      )}

      <View className="flex-row space-x-2 mb-4">
        <Button onPress={refreshData} className="flex-1">
          <ButtonText>Refresh Data</ButtonText>
        </Button>
        <Button onPress={testUpdateLocation} className="flex-1 bg-warning-500">
          <ButtonText>Test Update</ButtonText>
        </Button>
      </View>

      <ScrollView className="max-h-48">
        <Text className="font-bold">
          Firebase User ID: {user?.uid || "Not logged in"}
        </Text>
        <Text className="font-bold mt-2">Locations in Database:</Text>
        <Text className="font-mono text-xs">
          {locationData
            ? JSON.stringify(locationData, null, 2)
            : "No location data"}
        </Text>
      </ScrollView>
    </View>
  );
};

export default LocationDebug;
