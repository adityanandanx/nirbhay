import numpy as np
import wave
import os

def calculate_volume(audio_data):
    """Calculate the RMS volume of a given audio chunk."""
    audio_array = np.frombuffer(audio_data, dtype=np.int16)
    rms = np.sqrt(np.mean(np.square(audio_array)))
    return rms

def save_audio(filename, frames, sample_rate=16000, channels=1, sample_width=2):
    """Save recorded audio frames to a WAV file."""
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with wave.open(filename, 'wb') as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(sample_width)
        wf.setframerate(sample_rate)
        wf.writeframes(b''.join(frames))
