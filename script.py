import serial
import time
import os

csv_file_path = "D:\\Btech\\PRIDE dataset\\User17\\Dataset\\ACDS.csv"   
arduino_port = "COM8"             
baud_rate = 115200

def send_csv(file_path, port, baud):
    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
        return

    try:
        ser = serial.Serial(port, baud, timeout=2)
        time.sleep(2)  # Wait for Arduino to reset
        print("Connected to Arduino.")
    except serial.SerialException:
        print(f"Could not open serial port: {port}")
        return

    print(f"Sending CSV from '{file_path}'...\n")

    with open(file_path, 'r') as file:
        for idx, line in enumerate(file):
            clean_line = line.strip()
            if clean_line:
                ser.write((clean_line + '\n').encode('utf-8'))
                print(f"[{idx}] Sent: {clean_line}")
                
                # 🔄 Wait for Arduino to respond with "OK" (optional safety)
                try:
                    ack = ser.readline().decode().strip()
                    if ack != "OK":
                        print(f"Warning: Unexpected ACK -> {ack}")
                except:
                    print("No ACK received.")

                time.sleep(0.15)  # Give Arduino time to process

    print("\n✅ Done sending CSV.")
    ser.close()

# === MAIN ===
if __name__ == "__main__":
    send_csv(csv_file_path, arduino_port, baud_rate)
