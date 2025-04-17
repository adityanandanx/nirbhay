import { useEffect, useState } from "react";
import * as Location from "expo-location";
import auth from "@react-native-firebase/auth";
import database from "@react-native-firebase/database";
import firestore from "@react-native-firebase/firestore";

export type ContactLocation = {
  id: string;
  name: string;
  phoneNumber: string;
  location: {
    latitude: number;
    longitude: number;
    timestamp: number;
  } | null;
};

export const useContactsLocations = () => {
  const [myLocation, setMyLocation] = useState<Location.LocationObject | null>(
    null
  );
  const [contactsLocations, setContactsLocations] = useState<ContactLocation[]>(
    []
  );
  const [locationPermission, setLocationPermission] = useState<boolean>(false);
  const [loading, setLoading] = useState<boolean>(true);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const user = auth().currentUser;

  // Get location permission and start tracking
  useEffect(() => {
    const setupLocationTracking = async () => {
      try {
        const { status } = await Location.requestForegroundPermissionsAsync();
        const permissionGranted = status === "granted";
        setLocationPermission(permissionGranted);

        if (!permissionGranted) {
          setErrorMsg("Permission to access location was denied");
          setLoading(false);
          return;
        }

        // Get initial location
        const location = await Location.getCurrentPositionAsync({
          accuracy: Location.Accuracy.Balanced,
        });
        setMyLocation(location);

        // Set up location tracking
        const locationSubscription = await Location.watchPositionAsync(
          {
            accuracy: Location.Accuracy.Balanced,
            timeInterval: 5000,
            distanceInterval: 10,
          },
          (newLocation) => {
            setMyLocation(newLocation);

            // Update location in Firebase if user is authenticated
            if (user) {
              updateMyLocationInFirebase(newLocation);
            }
          },
          (reason) => {
            console.error("Location tracking error:", reason);
            setErrorMsg("Error tracking location");
          }
        );

        // Return cleanup function
        return () => {
          locationSubscription.remove();
        };
      } catch (error) {
        setErrorMsg("Error setting up location tracking");
        console.error(error);
      } finally {
        setLoading(false);
      }
    };

    setupLocationTracking();
  }, [user?.uid]);

  // Update my location in Firebase Realtime Database
  const updateMyLocationInFirebase = async (
    location: Location.LocationObject
  ) => {
    if (!user) return;

    try {
      // Get the database reference (with optional custom URL)
      const db = database();

      console.log("Attempting to update location in Firebase:", {
        lat: location.coords.latitude,
        lng: location.coords.longitude,
        uid: user.uid,
      });

      await db.ref(`/locations/${user.uid}`).update({
        latitude: location.coords.latitude,
        longitude: location.coords.longitude,
        timestamp: database.ServerValue.TIMESTAMP, // Use server timestamp for consistency
        phoneNumber: user.phoneNumber || "",
        displayName: user.displayName || "",
        email: user.email || "",
      });

      console.log("Successfully updated location in Firebase");

      // Verify the data was written by reading it back
      const snapshot = await db.ref(`/locations/${user.uid}`).once("value");
      console.log("Current location data in database:", snapshot.val());
    } catch (error) {
      console.error("Error updating location in Firebase:", error);
    }
  };

  // Fetch contacts from Firestore and prepare for location tracking
  useEffect(() => {
    if (!user) return;

    // Get user's contacts from Firestore (contacts list is still in Firestore)
    const contactsSubscriber = firestore()
      .collection(`users/${user.uid}/contacts`)
      .onSnapshot(async (querySnapshot) => {
        // Process contacts to prepare for Realtime Database lookups
        const contactsList: ContactLocation[] = querySnapshot.docs.map(
          (doc) => {
            const contactData = doc.data();
            return {
              id: doc.id,
              name: contactData.name,
              phoneNumber: contactData.phoneNumber,
              location: null, // Will be populated from Realtime Database
            };
          }
        );

        setContactsLocations(contactsList);
      });

    return () => contactsSubscriber();
  }, [user?.uid]);

  // Listen for location updates from contacts using Realtime Database
  useEffect(() => {
    if (!user || contactsLocations.length === 0) return;

    console.log(
      "Setting up location listeners for contacts:",
      contactsLocations.length
    );

    // Fetch phone numbers of all users in the system to map to contacts
    const fetchPhoneToUserIdMap = async () => {
      try {
        // This is still using Firestore to get the mapping between phone numbers and user IDs
        const usersSnapshot = await firestore().collection("users").get();
        const phoneToUserIdMap = new Map();

        usersSnapshot.docs.forEach((doc) => {
          const userData = doc.data();
          if (userData.phoneNumber) {
            const normalizedPhone = userData.phoneNumber.replace(/\s/g, "");
            phoneToUserIdMap.set(normalizedPhone, doc.id);
          }
        });

        return phoneToUserIdMap;
      } catch (error) {
        console.error("Error fetching users:", error);
        return new Map();
      }
    };

    // Listen for all location updates in the Realtime Database
    const setupLocationListeners = async () => {
      try {
        const phoneToUserIdMap = await fetchPhoneToUserIdMap();
        console.log(
          "Phone to user ID map created:",
          Array.from(phoneToUserIdMap.entries()).length,
          "entries"
        );

        // Create a reference to the locations node in Realtime Database
        const db = database();
        const locationsRef = db.ref("/locations");
        console.log("Listening for location updates at path: /locations");

        // Listen for changes - using 'value' event to get all locations at once
        locationsRef.on(
          "value",
          (snapshot) => {
            const locationsData = snapshot.val() || {};
            console.log(
              "Received location updates:",
              Object.keys(locationsData).length,
              "locations available"
            );

            // Update our contacts with location data if available
            setContactsLocations((prevContacts) => {
              return prevContacts.map((contact) => {
                // Find the user ID for this contact's phone number
                const normalizedPhone = contact.phoneNumber.replace(/\s/g, "");
                const userId = phoneToUserIdMap.get(normalizedPhone);

                // If we have location data for this user
                if (userId && locationsData[userId]) {
                  console.log(
                    "Found location for contact:",
                    contact.name,
                    locationsData[userId].latitude,
                    locationsData[userId].longitude
                  );

                  return {
                    ...contact,
                    id: userId, // Update with the real user ID
                    location: {
                      latitude: locationsData[userId].latitude,
                      longitude: locationsData[userId].longitude,
                      timestamp: locationsData[userId].timestamp,
                    },
                  };
                }
                return contact;
              });
            });
          },
          (error) => {
            console.error("Error listening to location updates:", error);
          }
        );

        // Return cleanup function
        return () => {
          console.log("Removing location listeners");
          locationsRef.off("value");
        };
      } catch (error) {
        console.error("Error setting up location listeners:", error);
      }
    };

    // Set up the location listeners and store the cleanup function
    const cleanupPromise = setupLocationListeners();

    return () => {
      // Execute the cleanup when the component unmounts
      cleanupPromise.then((cleanup) => {
        if (cleanup) cleanup();
      });
    };
  }, [user?.uid, contactsLocations.length]);

  return {
    myLocation,
    contactsLocations,
    locationPermission,
    loading,
    errorMsg,
  };
};
