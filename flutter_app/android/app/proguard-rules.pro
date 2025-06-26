# Keep TensorFlow Lite GPU Delegate classes
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

# This also keeps classes required by TFLite
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**
