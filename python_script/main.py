import speech_recognition as sr
import pyaudio
import wave
import time
import os
import numpy as np
from datetime import datetime
import matplotlib.pyplot as plt

# ====== CONFIGURATION ======
LISTEN_DURATION = 30
CHUNK = 2048  # Increased chunk size for better audio handling
FORMAT = pyaudio.paInt16
CHANNELS = 1
RATE = 16000
VOLUME_THRESHOLD = 1000
DISTRESS_KEYWORDS = ["help", "please help me", "bachao", "choro"]
SAFE_PHRASE = "safe"
AUDIO_SAVE_DIR = "audio_logs"
PLOT_UPDATE_INTERVAL = 20  # Update plot every 20 chunks to reduce lag

# ====== INITIALIZE ======
recognizer = sr.Recognizer()
audio_interface = pyaudio.PyAudio()

# Matplotlib setup
plt.switch_backend('TkAgg')
fig, (ax1, ax2) = plt.subplots(2, 1)
vol_buffer = np.zeros(100)  # Buffer for smoother volume display
timestamps = np.linspace(0, 5, 100)  # 5-second window
recent_words = []

def update_plot():
    """Optimized plot update with buffer"""
    try:
        ax1.clear()
        ax1.plot(timestamps, vol_buffer, 'r-')
        ax1.axhline(y=VOLUME_THRESHOLD, color='g', linestyle='--')
        ax1.set_ylabel('Volume (RMS)')
        ax1.set_ylim(0, 5000)
        
        ax2.clear()
        display_text = "Last Detected Words:\n" + "\n".join(recent_words[-3:])
        ax2.text(0.1, 0.5, display_text, fontsize=10, va='center')
        ax2.axis('off')
        
        plt.tight_layout()
        plt.draw()
        plt.pause(0.01)
    except Exception as e:
        print(f"Plot error: {str(e)}")

def calculate_volume(audio_data):
    audio_array = np.frombuffer(audio_data, dtype=np.int16).astype(np.float32)
    if len(audio_array) == 0:
        return 0
    return np.sqrt(np.mean(np.square(audio_array)))


def save_audio(filename, frames):
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    print(f"\n💾 Saving {filename}...")
    with wave.open(filename, 'wb') as wf:
        wf.setnchannels(CHANNELS)
        wf.setsampwidth(2)
        wf.setframerate(RATE)
        wf.writeframes(b''.join(frames))
    print(f"✅ Saved {filename} (Length: {len(frames)*CHUNK/RATE:.1f}s)")

def listen_for_speech(timeout=2):
    with sr.Microphone(sample_rate=RATE) as source:
        try:
            return recognizer.listen(source, timeout=timeout, 
                                   phrase_time_limit=timeout)
        except sr.WaitTimeoutError:
            return None

def start_recording_loop(filename):
    print("\n🔴 RECORDING STARTED... Press Ctrl+C to stop recording manually.")
    stream = audio_interface.open(format=FORMAT, channels=CHANNELS,
                                  rate=RATE, input=True, 
                                  frames_per_buffer=CHUNK)

    frames = []
    try:
        while True:
            data = stream.read(CHUNK)
            frames.append(data)

            # Volume monitoring + plotting (optional)
            vol = calculate_volume(data)
            vol_buffer[:-1] = vol_buffer[1:]
            vol_buffer[-1] = vol

            if len(frames) % PLOT_UPDATE_INTERVAL == 0:
                update_plot()
                print(f"📊 Real-time Volume: {vol:.1f}", end='\r')

    except KeyboardInterrupt:
        print("\n🛑 Manual stop detected. Saving audio...")

    finally:
        stream.stop_stream()
        stream.close()
        plt.close()
        save_audio(filename, frames)


def main():
    print("🚀 Safety System Activated")
    os.makedirs(AUDIO_SAVE_DIR, exist_ok=True)
    
    try:
        start_time = time.time()
        while time.time() - start_time < LISTEN_DURATION:
            audio = listen_for_speech()
            
            if audio:
                # Volume check
                volume = calculate_volume(audio.get_raw_data())
                print(f"📢 Initial Volume: {volume}")
                
                # Speech recognition
                try:
                    text = recognizer.recognize_google(audio).lower()
                    recent_words.append(text)
                    print(f"🔍 Heard: {text}")

                    if any(kw in text for kw in DISTRESS_KEYWORDS):
                        filename = f"distress_{datetime.now().strftime('%Y-%m-%d_%H-%M-%S')}.wav"
                        start_recording_loop(os.path.join(AUDIO_SAVE_DIR, filename))
                        return

                except sr.UnknownValueError:
                    print("🔇 No speech understood")

                except sr.RequestError as e:
                    print(f"❌ Recognition failed: {e}")

                # Trigger recording if loud noise
                if volume > VOLUME_THRESHOLD:
                    filename = f"noise_{datetime.now().strftime('%Y-%m-%d_%H-%M-%S')}.wav"
                    start_recording_loop(os.path.join(AUDIO_SAVE_DIR, filename))
                    return
                    
        print("\n🕒 Monitoring period ended - No threats detected")
        
    except KeyboardInterrupt:
        print("\n🛑 System stopped by user")
    finally:
        audio_interface.terminate()

if __name__ == "__main__":
    main()