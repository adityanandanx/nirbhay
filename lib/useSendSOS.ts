import { useState } from "react";
import auth from "@react-native-firebase/auth";
import firestore from "@react-native-firebase/firestore";
import database from "@react-native-firebase/database";
import * as Location from "expo-location";

type SOSResult = {
  success: boolean;
  sentCount?: number;
  error?: string;
  timestamp?: number;
};

export const useSendSOS = () => {
  const [isLoading, setIsLoading] = useState(false);
  const [result, setResult] = useState<SOSResult | null>(null);

  const user = auth().currentUser;

  const sendSOS = async () => {
    if (!user) {
      setResult({
        success: false,
        error: "You must be logged in to send an emergency alert",
      });
      return;
    }

    setIsLoading(true);
    setResult(null);

    try {
      // 1. Get current location
      const location = await Location.getCurrentPositionAsync({
        accuracy: Location.Accuracy.High,
      });

      // 2. Create SOS alert in database
      const sosTimestamp = Date.now();
      const sosRef = database().ref(`/sos_alerts/${user.uid}`);
      await sosRef.set({
        latitude: location.coords.latitude,
        longitude: location.coords.longitude,
        accuracy: location.coords.accuracy,
        altitude: location.coords.altitude,
        heading: location.coords.heading,
        speed: location.coords.speed,
        timestamp: sosTimestamp,
        active: true,
        user: {
          uid: user.uid,
          displayName: user.displayName || "",
          phoneNumber: user.phoneNumber || "",
          email: user.email || "",
        },
      });

      // 3. Get user's emergency contacts
      const contactsSnapshot = await firestore()
        .collection(`users/${user.uid}/contacts`)
        .get();

      const contacts = contactsSnapshot.docs.map((doc) => doc.data());

      // 4. Send notification to each contact
      const notificationPromises = contacts.map(async (contact) => {
        try {
          // Find the contact's user account by phone number
          const userQuery = await firestore()
            .collection("users")
            .where("phoneNumber", "==", contact.phoneNumber.replace(/\s/g, ""))
            .get();

          if (!userQuery.empty) {
            const contactUserId = userQuery.docs[0].id;

            // Create a notification for this contact
            await database()
              .ref(`/notifications/${contactUserId}`)
              .push({
                type: "SOS",
                title: "EMERGENCY SOS ALERT",
                message: `${
                  user.displayName || "Someone"
                } needs your urgent help!`,
                senderUid: user.uid,
                senderName: user.displayName || "",
                sosReference: `/sos_alerts/${user.uid}`,
                read: false,
                timestamp: database.ServerValue.TIMESTAMP,
              });

            return true;
          }
          return false;
        } catch (error) {
          console.error("Error sending notification to contact:", error);
          return false;
        }
      });

      const results = await Promise.all(notificationPromises);
      const sentCount = results.filter(Boolean).length;

      // 5. Return the result
      setResult({
        success: true,
        sentCount,
        timestamp: sosTimestamp,
      });
    } catch (error) {
      console.error("Error sending SOS:", error);
      setResult({
        success: false,
        error:
          "Failed to send emergency alert. Please try again or call emergency services directly.",
      });
    } finally {
      setIsLoading(false);
    }
  };

  return { sendSOS, isLoading, result };
};
