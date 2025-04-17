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
