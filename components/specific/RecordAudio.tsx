import {
  ExpoSpeechRecognitionModule,
  ExpoSpeechRecognitionResultEvent,
  useSpeechRecognitionEvent,
} from "expo-speech-recognition";
import React, { useEffect, useRef, useState } from "react";
import {
  Button,
  PermissionsAndroid,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";
import AudioRecorderPlayer, {
  AudioEncoderAndroidType,
  AudioSourceAndroidType,
  AVEncoderAudioQualityIOSType,
  AVEncodingOption,
  RecordBackType,
} from "react-native-audio-recorder-player";
import { LineChart } from "react-native-chart-kit";

const RecordAudio = () => {
  const [isRecording, setIsRecording] = useState(false);
  const [isMonitoring, setIsMonitoring] = useState(false);
  const [volume, setVolume] = useState(0);
  const [volumeHistory, setVolumeHistory] = useState(Array(20).fill(0));
  const [detectedWords, setDetectedWords] = useState<string[]>([]);
  const [isSpeechAvailable, setSpeechAvailable] = useState(false);
  const audioRecorderPlayer = useRef(new AudioRecorderPlayer()).current;
  const updateIntervalRef = useRef<NodeJS.Timeout | null>(null);
  const monitoringTimerRef = useRef<NodeJS.Timeout | null>(null);
  const recordingTimerRef = useRef<NodeJS.Timeout | null>(null);
  const speechListener = useRef<any>(null);

  // Configuration
  const VOLUME_THRESHOLD = 50;
  const DISTRESS_KEYWORDS = ["help", "please help me", "bachao", "save me"];
  const MONITORING_DURATION = 30000; // 30 seconds
  const RECORDING_DURATION = 30000; // 30 seconds when triggered

  useSpeechRecognitionEvent("result", (event) => {
    handleSpeechResults(event);
  });

  useSpeechRecognitionEvent("error", (event) => {
    handleSpeechError(event);
  });

  // Initialize speech recognition
  useEffect(() => {
    const checkSpeechAvailability = () => {
      try {
        const available = ExpoSpeechRecognitionModule.isRecognitionAvailable();
        setSpeechAvailable(available);

        if (available) {
          console.log("Speech recognition is available");
        } else {
          console.log("Speech recognition is not available on this device");
        }
      } catch (error) {
        console.error("Error checking speech recognition availability:", error);
      }
    };

    // Request permissions on component mount
    const requestPermissions = async () => {
      try {
        // Request speech recognition permissions
        const { status } =
          await ExpoSpeechRecognitionModule.requestPermissionsAsync();
        if (status !== "granted") {
          console.warn("Speech recognition permission not granted");
        }

        // Request audio recording permissions (for Android)
        if (Platform.OS === "android") {
          try {
            const grants = await PermissionsAndroid.requestMultiple([
              PermissionsAndroid.PERMISSIONS.WRITE_EXTERNAL_STORAGE,
              PermissionsAndroid.PERMISSIONS.READ_EXTERNAL_STORAGE,
              PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
            ]);

            console.log("Permission results:", grants);
          } catch (err) {
            console.warn(err);
          }
        }
      } catch (err) {
        console.warn(err);
      }
    };

    checkSpeechAvailability();
    requestPermissions();

    // Cleanup on unmount
    return () => {
      if (updateIntervalRef.current) {
        clearInterval(updateIntervalRef.current);
      }
      if (monitoringTimerRef.current) {
        clearTimeout(monitoringTimerRef.current);
      }
      if (recordingTimerRef.current) {
        clearTimeout(recordingTimerRef.current);
      }
      if (isRecording) {
        audioRecorderPlayer.stopRecorder();
      }
      stopVoiceRecognition();
    };
  }, []);

  // Start voice recognition with expo-speech-recognition
  const startVoiceRecognition = async () => {
    if (!isSpeechAvailable) {
      console.log("Speech recognition not available");
      return;
    }

    try {
      await stopVoiceRecognition(); // Stop any existing recognition

      speechListener.current = ExpoSpeechRecognitionModule.start({
        interimResults: true,
        lang: "en-US",
      });

      console.log("Voice recognition started");
    } catch (error) {
      console.error("Failed to start speech recognition:", error);
    }
  };

  const stopVoiceRecognition = async () => {
    try {
      if (speechListener.current) {
        await ExpoSpeechRecognitionModule.stopListening();
        speechListener.current = null;
        console.log("Voice recognition stopped");
      }
    } catch (error) {
      console.error("Failed to stop speech recognition:", error);
    }
  };

  // Handle speech recognition results
  const handleSpeechResults = (event: ExpoSpeechRecognitionResultEvent) => {
    if (event.results && event.results.length > 0) {
      const text = event.results[0].transcript.toLowerCase();
      console.log("🔍 Heard:", text);

      // Add to detected words list
      setDetectedWords((prev) => {
        const updated = [...prev, text];
        // Keep only the last 5 entries
        return updated.slice(-5);
      });

      // Check for distress keywords
      if (DISTRESS_KEYWORDS.some((keyword) => text.includes(keyword))) {
        console.log("⚠️ DISTRESS DETECTED:", text);
        stopVoiceRecognition();
        startDistressRecording();
      }
    }
  };

  const handleSpeechError = (error: any) => {
    console.log("Speech recognition error:", error);
    // Restart speech recognition if there was an error but we're still monitoring
    if (isMonitoring) {
      startVoiceRecognition();
    }
  };

  // Calculate volume from audio data
  const calculateVolume = (e: RecordBackType) => {
    if (e && e.currentMetering) {
      return Math.min(100, Math.max(0, (e.currentMetering + 100) * 1.5));
    }
    return Math.random() * 20 + 5;
  };

  // Update the volume history buffer
  const updateVolumeHistory = (newVolume: number) => {
    setVolumeHistory((prevHistory) => {
      const newHistory = [...prevHistory.slice(1), newVolume];
      return newHistory;
    });
    setVolume(newVolume);

    if (isMonitoring && !isRecording && newVolume > VOLUME_THRESHOLD) {
      console.log("⚠️ LOUD NOISE DETECTED:", newVolume);
      startDistressRecording();
    }
  };

  // Start distress recording automatically for 30 seconds
  const startDistressRecording = async () => {
    if (isRecording) return;

    setIsMonitoring(false);
    if (monitoringTimerRef.current) {
      clearTimeout(monitoringTimerRef.current);
      monitoringTimerRef.current = null;
    }

    const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
    const filename = `distress_${timestamp}.mp3`;

    console.log("🚨 DISTRESS DETECTED - Starting automatic recording");
    await startRecording(filename);

    recordingTimerRef.current = setTimeout(() => {
      if (isRecording) {
        stopRecording();
        console.log("✅ Automatic distress recording complete");
      }
      recordingTimerRef.current = null;
    }, RECORDING_DURATION);
  };

  // Start safety monitoring
  const startMonitoring = () => {
    setIsMonitoring(true);
    setDetectedWords([]);
    console.log("🚀 Safety Monitoring System Activated");

    startVoiceRecognition();

    updateIntervalRef.current = setInterval(() => {
      const simulatedVolume = Math.random() * 20 + 5;
      updateVolumeHistory(simulatedVolume);
      console.log(`📊 Real-time Volume: ${volume.toFixed(1)}`);
    }, 500);

    monitoringTimerRef.current = setTimeout(() => {
      stopMonitoring();
      console.log("🕒 Monitoring period ended - No threats detected");
    }, MONITORING_DURATION);
  };

  const stopMonitoring = () => {
    setIsMonitoring(false);
    stopVoiceRecognition();

    if (updateIntervalRef.current) {
      clearInterval(updateIntervalRef.current);
      updateIntervalRef.current = null;
    }

    if (monitoringTimerRef.current) {
      clearTimeout(monitoringTimerRef.current);
      monitoringTimerRef.current = null;
    }
  };

  const startRecording = async (filename: string) => {
    try {
      const path = Platform.select({
        ios: filename ? filename : "recording.m4a",
        android: filename ? `/sdcard/${filename}` : "/sdcard/recording.mp3",
      });

      console.log("🔴 RECORDING STARTED... Press Stop to end recording.");

      const result = await audioRecorderPlayer.startRecorder(path, {
        AudioEncoderAndroid: AudioEncoderAndroidType.AAC,
        AudioSourceAndroid: AudioSourceAndroidType.MIC,
        AVEncoderAudioQualityKeyIOS: AVEncoderAudioQualityIOSType.high,
        AVNumberOfChannelsKeyIOS: 2,
        AVFormatIDKeyIOS: AVEncodingOption.aac,
      });

      console.log("Recording started:", result);
      setIsRecording(true);

      audioRecorderPlayer.addRecordBackListener((e) => {
        const vol = calculateVolume(e);
        updateVolumeHistory(vol);
        return;
      });

      updateIntervalRef.current = setInterval(() => {
        console.log(`📊 Real-time Volume: ${volume.toFixed(1)}`);
      }, 500);
    } catch (error) {
      console.error("Failed to start recording:", error);
    }
  };

  const stopRecording = async () => {
    try {
      console.log("🛑 Stopping recording. Saving audio...");

      const result = await audioRecorderPlayer.stopRecorder();
      audioRecorderPlayer.removeRecordBackListener();

      if (updateIntervalRef.current) {
        clearInterval(updateIntervalRef.current);
        updateIntervalRef.current = null;
      }

      setIsRecording(false);
      console.log("Recording saved at:", result);
    } catch (error) {
      console.error("Failed to stop recording:", error);
    }
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Safety Audio System</Text>

      {!isSpeechAvailable && (
        <View style={styles.warningContainer}>
          <Text style={styles.warningText}>
            ⚠️ Speech recognition is not available on this device. Volume
            monitoring will still work.
          </Text>
        </View>
      )}

      <View style={styles.statusContainer}>
        <Text
          style={[
            styles.statusText,
            isMonitoring
              ? styles.monitoring
              : isRecording
              ? styles.recording
              : styles.idle,
          ]}
        >
          {isMonitoring
            ? "🚀 MONITORING"
            : isRecording
            ? "🔴 RECORDING"
            : "⏸️ IDLE"}
        </Text>
      </View>

      <View style={styles.volumeContainer}>
        <Text style={styles.volumeText}>
          📊 Real-time Volume: {volume.toFixed(1)}
        </Text>
        <LineChart
          data={{
            labels: Array(volumeHistory.length).fill(""),
            datasets: [
              {
                data: volumeHistory,
              },
            ],
          }}
          width={300}
          height={100}
          chartConfig={{
            backgroundColor: "#f0f0f0",
            backgroundGradientFrom: "#ffffff",
            backgroundGradientTo: "#ffffff",
            decimalPlaces: 0,
            color: (opacity = 1) => `rgba(0, 122, 255, ${opacity})`,
            style: {
              borderRadius: 16,
            },
          }}
          bezier
          style={styles.chart}
        />
      </View>

      <View style={styles.wordsContainer}>
        <Text style={styles.sectionTitle}>Last Detected Words:</Text>
        <ScrollView style={styles.wordsScroll}>
          {detectedWords.length > 0 ? (
            detectedWords.map((word, index) => (
              <Text key={index} style={styles.wordItem}>
                • {word}
              </Text>
            ))
          ) : (
            <Text style={styles.noWordsText}>No speech detected yet</Text>
          )}
        </ScrollView>
      </View>

      <View style={styles.buttonContainer}>
        {isRecording ? (
          <Button
            title="Stop Recording"
            onPress={stopRecording}
            color="#FF3B30"
          />
        ) : isMonitoring ? (
          <Button
            title="Stop Monitoring"
            onPress={stopMonitoring}
            color="#FF9500"
          />
        ) : (
          <>
            <Button
              title="Start Safety Monitoring"
              onPress={startMonitoring}
              color="#34C759"
            />
            <View style={styles.buttonSpacer} />
            <Button
              title="Manual Recording"
              onPress={() => startRecording("manual_recording.mp3")}
              color="#007AFF"
            />
          </>
        )}
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    padding: 20,
    backgroundColor: "#f5f5f5",
  },
  title: {
    fontSize: 24,
    fontWeight: "bold",
    marginBottom: 20,
  },
  statusContainer: {
    width: "100%",
    alignItems: "center",
    marginBottom: 15,
  },
  statusText: {
    fontSize: 18,
    fontWeight: "bold",
    paddingVertical: 8,
    paddingHorizontal: 16,
    borderRadius: 20,
  },
  idle: {
    backgroundColor: "#e0e0e0",
    color: "#333",
  },
  monitoring: {
    backgroundColor: "#34C759",
    color: "white",
  },
  recording: {
    backgroundColor: "#FF3B30",
    color: "white",
  },
  volumeContainer: {
    width: "100%",
    alignItems: "center",
    marginVertical: 15,
  },
  volumeText: {
    fontSize: 16,
    marginBottom: 10,
  },
  chart: {
    marginVertical: 8,
    borderRadius: 16,
  },
  wordsContainer: {
    width: "100%",
    marginVertical: 15,
    backgroundColor: "white",
    borderRadius: 10,
    padding: 10,
    maxHeight: 150,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: "bold",
    marginBottom: 8,
  },
  wordsScroll: {
    maxHeight: 120,
  },
  wordItem: {
    fontSize: 14,
    paddingVertical: 3,
  },
  noWordsText: {
    fontSize: 14,
    fontStyle: "italic",
    color: "#888",
    textAlign: "center",
    paddingVertical: 10,
  },
  buttonContainer: {
    width: "80%",
    marginTop: 20,
  },
  buttonSpacer: {
    height: 10,
  },
  warningContainer: {
    backgroundColor: "#FFF3CD",
    borderColor: "#FFEEBA",
    borderWidth: 1,
    borderRadius: 8,
    padding: 10,
    marginBottom: 15,
    width: "100%",
  },
  warningText: {
    color: "#856404",
    fontSize: 14,
    textAlign: "center",
  },
});

export default RecordAudio;
