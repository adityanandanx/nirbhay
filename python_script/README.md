# Voice-Based Women's Safety System

This project is a Python-based safety system that listens for distress signals. When activated, it listens for 30 seconds and checks for:

- Distress keywords (e.g., "help", "bachao", "please help me")
- Loud sounds (screaming, moaning, or any very loud noise)

If a distress signal is detected, the system:

- Outputs `1`
- Starts recording audio continuously
- Saves the audio with a timestamped filename in the `audio_logs/` folder
- Keeps recording until the user says a safe phrase like **"I am safe"**

If no distress signal is detected within 30 seconds, it outputs `0` and stops listening.

---

## 🚧 Development Status

This project is currently in the **development phase**. More features and improvements will be added soon.

---

## 📦 Requirements

- Python 3.7 or higher
- Internet connection (used for speech recognition)

Install required packages:

```bash
pip install -r requirements.txt
```

---

## ▶️ How to Run

To start the system, run:

```bash
python main.py
```

---

## 📁 Project Structure

```
voice-safety-system/
│
├── main.py                  # Main program logic
├── utils/
│   └── audio_tools.py       # Helper functions for audio detection and saving
├── audio_logs/              # Folder to store recorded audio files
├── requirements.txt         # Python dependencies
└── README.md                # Project overview (this file)
```

---
