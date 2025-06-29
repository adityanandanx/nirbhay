# train_model.py
# Run this script after setting up UV environment

import tensorflow as tf
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import classification_report, confusion_matrix
import matplotlib.pyplot as plt
import os
import json  

class FightFlightDetector:
    def __init__(self, batch_size=8):    
        self.batch_size = batch_size
        self.scaler = StandardScaler()
        self.model = None
        self.user_baseline = None
        
    def load_user_calibration(self, calibration_file='calibration.csv'):
        """Load user's baseline data for calibration"""
        try:
            user_df = pd.read_csv(calibration_file)
            # Calculate baseline metrics from user's normal state data
            self.user_baseline = {
                'avg_hr': float(user_df['hr'].mean()),
                'rmssd': float(self.calculate_rmssd(user_df['hr'].values)),
                'avg_accel_mag': float(np.sqrt(
                    user_df['ax']**2 + user_df['ay']**2 + user_df['az']**2
                ).mean()),
                'avg_gyro_mag': float(np.sqrt(
                    user_df['gx']**2 + user_df['gy']**2 + user_df['gz']**2
                ).mean())
            }
            print("User calibration data loaded successfully")
            print(f"Baseline values: {json.dumps(self.user_baseline, indent=2)}")
        except Exception as e:
            print(f"Warning: Could not load user calibration data: {str(e)}")
            print("Using default values for thresholds")
            self.user_baseline = {}
            
    def calculate_rmssd(self, hr_values):
        """Calculate RMSSD from heart rate values"""
        if len(hr_values) < 2:
            return 0.0
        
        # Convert BPM to RR intervals (milliseconds)
        rr_intervals = []
        for hr in hr_values:
            if hr > 0:
                rr_intervals.append(60000.0 / hr)
        
        if len(rr_intervals) < 2:
            return 0.0
            
        # Calculate successive differences
        rr_intervals = np.array(rr_intervals)
        diff = np.diff(rr_intervals)
        
        # Calculate RMSSD
        rmssd = np.sqrt(np.mean(diff ** 2))
        return rmssd
    
    def engineer_features(self, batch_data):
        """Engineer features from raw sensor data batch"""
        hr_values = batch_data[:, 0]
        accel_data = batch_data[:, 1:4]  # ax, ay, az
        gyro_data = batch_data[:, 4:7]   # gx, gy, gz
        
        # Heart Rate Features
        avg_hr = np.mean(hr_values)
        max_hr = np.max(hr_values)
        min_hr = np.min(hr_values)
        std_hr = np.std(hr_values)
        rmssd = self.calculate_rmssd(hr_values)
        
        # Accelerometer Features
        accel_mag = np.sqrt(np.sum(accel_data ** 2, axis=1))
        avg_accel_mag = np.mean(accel_mag)
        max_accel_mag = np.max(accel_mag)
        std_accel_mag = np.std(accel_mag)
        
        # Individual accelerometer axis statistics
        avg_ax, avg_ay, avg_az = np.mean(accel_data, axis=0)
        std_ax, std_ay, std_az = np.std(accel_data, axis=0)
        
        # Gyroscope Features
        gyro_mag = np.sqrt(np.sum(gyro_data ** 2, axis=1))
        avg_gyro_mag = np.mean(gyro_mag)
        max_gyro_mag = np.max(gyro_mag)
        std_gyro_mag = np.std(gyro_mag)
        
        # Individual gyroscope axis statistics
        avg_gx, avg_gy, avg_gz = np.mean(gyro_data, axis=0)
        std_gx, std_gy, std_gz = np.std(gyro_data, axis=0)
        
        # Combined features with dynamic thresholds based on user calibration
        baseline = self.user_baseline or {}
        
        # Heart rate and HRV stress indicators with personalized thresholds
        hr_stress_indicator = (
            avg_hr > baseline.get('avg_hr', 100) + 15 and  # 15 BPM above baseline
            rmssd < baseline.get('rmssd', 30) * 0.7 and    # Below 70% of baseline
            rmssd > baseline.get('rmssd', 30) * 0.2        # Above 20% of baseline
        )
        
        # Motion stress indicators with personalized thresholds
        sensor_stress_indicator = (
            avg_accel_mag > baseline.get('avg_accel_mag', 1.02) * 1.5 and  # 50% above baseline
            avg_gyro_mag > baseline.get('avg_gyro_mag', 20.0) * 1.5        # 50% above baseline
        )
        
        features = [
            # HR features
            avg_hr, max_hr, min_hr, std_hr, rmssd,
            # Accel features
            avg_accel_mag, max_accel_mag, std_accel_mag,
            avg_ax, avg_ay, avg_az, std_ax, std_ay, std_az,
            # Gyro features
            avg_gyro_mag, max_gyro_mag, std_gyro_mag,
            avg_gx, avg_gy, avg_gz, std_gx, std_gy, std_gz,
            # Combined indicators
            float(hr_stress_indicator), float(sensor_stress_indicator)
        ]
        
        return np.array(features)
    
    def prepare_batches(self, data, labels):
        """Prepare batched data for training"""
        X_batches = []
        y_batches = []
        
        # Group data into batches
        for i in range(0, len(data) - self.batch_size + 1, self.batch_size):
            batch = data[i:i + self.batch_size]
            batch_labels = labels[i:i + self.batch_size]
            
            # Engineer features for this batch
            features = self.engineer_features(batch)
            X_batches.append(features)
            
            # Use majority vote for batch label
            batch_label = 1 if np.mean(batch_labels) > 0.5 else 0
            y_batches.append(batch_label)
        
        return np.array(X_batches), np.array(y_batches)
    
    def build_model(self, input_shape):
        """Build the neural network model"""
        model = tf.keras.Sequential([
            tf.keras.layers.Input(shape=(input_shape,)),
            
            # First hidden layer
            tf.keras.layers.Dense(128, activation='relu'),
            tf.keras.layers.BatchNormalization(),
            tf.keras.layers.Dropout(0.3),
            
            # Second hidden layer
            tf.keras.layers.Dense(64, activation='relu'),
            tf.keras.layers.BatchNormalization(),
            tf.keras.layers.Dropout(0.3),
            
            # Third hidden layer
            tf.keras.layers.Dense(32, activation='relu'),
            tf.keras.layers.Dropout(0.2),
            
            # Output layer
            tf.keras.layers.Dense(1, activation='sigmoid')
        ])
        
        model.compile(
            optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
            loss='binary_crossentropy',
            metrics=['accuracy', 'precision', 'recall']
        )
        
        return model
    
    def load_data(self, csv_file):
        """Load and preprocess data from CSV file"""
        try:
            # Try reading with header detection
            df = pd.read_csv(csv_file)
            if len(df.columns) == 8:  # has header
                df.columns = ['hr', 'ax', 'ay', 'az', 'gx', 'gy', 'gz', 'label']
            else:
                # Read without header
                df = pd.read_csv(csv_file, header=None, 
                               names=['hr', 'ax', 'ay', 'az', 'gx', 'gy', 'gz', 'label'])
        except:
            # Fallback to no header
            df = pd.read_csv(csv_file, header=None, 
                           names=['hr', 'ax', 'ay', 'az', 'gx', 'gy', 'gz', 'label'])
        
        # Convert labels to binary
        df['label_binary'] = (df['label'] == 'atypical').astype(int)
        
        # Extract features and labels
        features = df[['hr', 'ax', 'ay', 'az', 'gx', 'gy', 'gz']].values
        labels = df['label_binary'].values
        
        print(f"Data loaded: {len(df)} samples")
        print(f"Label distribution: Typical={np.sum(labels==0)}, Atypical={np.sum(labels==1)}")
        
        return features, labels
    
    def train(self, csv_file, test_size=0.2, epochs=100):
        """Train the model"""
        print("Starting Fight-or-Flight Detection Model Training")
        print("=" * 50)
        
        print("Loading data...")
        data, labels = self.load_data(csv_file)
        
        print("Preparing batches...")
        X, y = self.prepare_batches(data, labels)
        
        print(f"Total batches: {len(X)}")
        print(f"Feature shape: {X.shape}")
        print(f"Labels distribution - Typical: {np.sum(y == 0)}, Atypical: {np.sum(y == 1)}")
        
        if len(X) < 10:
            print("Warning: Very small dataset. Consider collecting more data.")
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=test_size, random_state=42, stratify=y
        )
        
        # Scale features
        X_train_scaled = self.scaler.fit_transform(X_train)
        X_test_scaled = self.scaler.transform(X_test)
        
        # Build model
        print("Building model...")
        self.model = self.build_model(X_train_scaled.shape[1])
        
        print("Model Architecture:")
        self.model.summary()
        
        # Train model with callbacks
        early_stopping = tf.keras.callbacks.EarlyStopping(
            monitor='val_loss', patience=15, restore_best_weights=True
        )
        
        reduce_lr = tf.keras.callbacks.ReduceLROnPlateau(
            monitor='val_loss', factor=0.5, patience=10, min_lr=1e-6
        )
        
        print("Training model...")
        history = self.model.fit(
            X_train_scaled, y_train,
            epochs=epochs,
            batch_size=32,
            validation_data=(X_test_scaled, y_test),
            callbacks=[early_stopping, reduce_lr],
            verbose=1
        )
        
        # Evaluate model
        print("\nEvaluation Results:")
        print("=" * 30)
        test_loss, test_accuracy, test_precision, test_recall = self.model.evaluate(
            X_test_scaled, y_test, verbose=0
        )
        
        print(f"Test Accuracy: {test_accuracy:.4f}")
        print(f"Test Precision: {test_precision:.4f}")
        print(f"Test Recall: {test_recall:.4f}")
        
        # Predictions and detailed metrics
        y_pred_prob = self.model.predict(X_test_scaled, verbose=0)
        y_pred = (y_pred_prob > 0.5).astype(int).flatten()
        
        print("\nDetailed Classification Report:")
        print(classification_report(y_test, y_pred, 
                                  target_names=['Typical', 'Atypical']))
        
        print("\nConfusion Matrix:")
        print(confusion_matrix(y_test, y_pred))
        
        return history
    
    def convert_to_tflite(self, output_path='fight_flight_detector_with_calibration.tflite'):
        """Convert trained model to TensorFlow Lite"""
        if self.model is None:
            raise ValueError("Model not trained yet!")
        
        print("Converting to TensorFlow Lite...")
        
        # Convert to TensorFlow Lite
        converter = tf.lite.TFLiteConverter.from_keras_model(self.model)
        
        # Optimize for size and latency
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        
        # Use float16 quantization for smaller model size (corrected)
        converter.target_spec.supported_types = [tf.float16]
        
        tflite_model = converter.convert()
        
        # Save the model
        with open(output_path, 'wb') as f:
            f.write(tflite_model)
        
        print(f"TensorFlow Lite model saved to: {output_path}")
        print(f"Model size: {len(tflite_model) / 1024:.2f} KB")
        
        return tflite_model
    
    def save_scaler_params(self, output_path='scaler_params.json'):
        """Save scaler parameters as JSON for Android"""
        if self.scaler.mean_ is None:
            raise ValueError("Scaler not fitted yet!")
        
        # Feature names for reference (must match engineer_features order)
        feature_names = [
            'avg_hr', 'max_hr', 'min_hr', 'std_hr', 'rmssd',
            'avg_accel_mag', 'max_accel_mag', 'std_accel_mag',
            'avg_ax', 'avg_ay', 'avg_az', 'std_ax', 'std_ay', 'std_az',
            'avg_gyro_mag', 'max_gyro_mag', 'std_gyro_mag',
            'avg_gx', 'avg_gy', 'avg_gz', 'std_gx', 'std_gy', 'std_gz',
            'hr_stress_indicator', 'sensor_stress_indicator'
        ]
        
        scaler_params = {
            'feature_names': feature_names,
            'mean': self.scaler.mean_.tolist(),
            'scale': self.scaler.scale_.tolist(),
            'n_features': len(self.scaler.mean_),
            'scaling_formula': 'normalized_value = (raw_value - mean) / scale'
        }
        
        with open(output_path, 'w') as f:
            json.dump(scaler_params, f, indent=2)
        
        print(f"Scaler parameters saved to: {output_path}")
        print(f"Features: {len(feature_names)}")
        return scaler_params

def main():
    print("Fight-or-Flight Detection Model Training")
    print("=" * 50)
    
    # Use input.csv as the dataset for training/testing
    csv_file = 'input.csv'
    if not os.path.exists(csv_file):
        print(f"{csv_file} not found in current directory!")
        print("Please make sure input.csv exists.")
        return
    print(f"Using dataset: {csv_file}")
    
    # Initialize and train
    detector = FightFlightDetector(batch_size=8)
    try:
        # Load user calibration data from calibration.csv
        detector.load_user_calibration('calibration.csv')
        # Train the model
        history = detector.train(csv_file, epochs=100)
        # Convert to TensorFlow Lite
        detector.convert_to_tflite('fight_flight_detector_with_calibration.tflite')
        # Save scaler parameters as JSON (CHANGED THIS LINE)
        detector.save_scaler_params('scaler_params.json')
        print("\nTraining Complete!")
        print("=" * 30)
        print("fight_flight_detector_with_calibration.tflite - Ready for Android")
        print("scaler_params.json - Feature scaling parameters for Android")
        print("\nYour model is ready for Android integration!")
    except Exception as e:
        print(f"Error during training: {str(e)}")
        print("Please check your dataset format and try again.")

if __name__ == "__main__":
    main()

