import React, { useEffect, useState } from "react";
import { View } from "../ui/view";
import { Text } from "../ui/text";
import MapView, { Marker } from "react-native-maps";
import * as Location from "expo-location";

type Props = {};

const ContactsMap = (props: Props) => {
  const [location, setLocation] = useState<Location.LocationObject | null>(
    null
  );
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  useEffect(() => {
    async function getCurrentLocation() {
      let { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== "granted") {
        setErrorMsg("Permission to access location was denied");
        return;
      }

      let location = await Location.getCurrentPositionAsync({});
      setLocation(location);
    }

    getCurrentLocation();
  }, []);

  return (
    <View className="flex-1 h-96 w-full">
      <MapView
        style={{ flex: 1 }}
        showsMyLocationButton={true}
        showsUserLocation={true}
        showsTraffic={true}
        showsIndoors={true}
        showsBuildings={true}
        showsCompass={true}
        showsScale={true}
        showsPointsOfInterest={true}
        showsIndoorLevelPicker={true}
        followsUserLocation={true}
        initialRegion={{
          latitude: location?.coords.latitude || 28.7041,
          longitude: location?.coords.longitude || 77.1025,
          latitudeDelta: 0.0922,
          longitudeDelta: 0.0421,
        }}
      ></MapView>
    </View>
  );
};

export default ContactsMap;
