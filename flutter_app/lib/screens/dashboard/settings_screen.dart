import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsStateProvider);
    final settingsNotifier = ref.watch(settingsStateProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body:
          settings.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Emergency Settings
                    _buildSectionCard(
                      'Emergency Settings',
                      Icons.emergency,
                      Colors.red,
                      [
                        _buildSwitchTile(
                          'Emergency Alerts',
                          'Automatically send alerts when threat is detected',
                          settings.emergencyAlertsEnabled,
                          (value) =>
                              settingsNotifier.setEmergencyAlertsEnabled(value),
                        ),
                        _buildSwitchTile(
                          'Location Sharing',
                          'Share location with emergency contacts',
                          settings.locationSharingEnabled,
                          (value) =>
                              settingsNotifier.setLocationSharingEnabled(value),
                        ),
                        _buildDropdownTile(
                          'SOS Countdown Timer',
                          'Time before emergency alert is sent',
                          settings.sosCountdownTime.toString(),
                          [10, 20, 30, 60].map((e) => e.toString()).toList(),
                          (value) => {
                            settingsNotifier.setSosCountdownTime(
                              int.parse(value!),
                            ),
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Safety Detection
                    _buildSectionCard(
                      'Safety Detection',
                      Icons.shield,
                      Colors.orange,
                      [
                        _buildSwitchTile(
                          'Automatic Threat Detection',
                          'Monitor vitals and movement patterns',
                          settings.automaticDetectionEnabled,
                          (value) => settingsNotifier
                              .setAutomaticDetectionEnabled(value),
                        ),
                        // _buildDropdownTile(
                        //   'Alert Sensitivity',
                        //   'Adjust detection sensitivity level',
                        //   settings.alertSensitivity,
                        //   ['Low', 'Medium', 'High'],
                        //   (value) =>
                        //       settingsNotifier.setAlertSensitivity(value!),
                        // ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Device Settings
                    _buildSectionCard(
                      'Device Settings',
                      Icons.watch,
                      Colors.blue,
                      [
                        // _buildSwitchTile(
                        //   'Vibration Alerts',
                        //   'Vibrate when alerts are triggered',
                        //   settings.vibrationEnabled,
                        //   (value) =>
                        //       settingsNotifier.setVibrationEnabled(value),
                        // ),
                        // _buildSwitchTile(
                        //   'Sound Alerts',
                        //   'Play sound for emergency notifications',
                        //   settings.soundEnabled,
                        //   (value) => settingsNotifier.setSoundEnabled(value),
                        // ),
                        _buildActionTile(
                          'Calibrate Sensors',
                          'Re-calibrate heart rate and motion sensors',
                          () => _calibrateSensors(),
                        ),
                        // _buildActionTile(
                        //   'Device Sync',
                        //   'Sync data with your wearable device',
                        //   () => _syncDevice(),
                        // ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Security & Privacy
                    _buildSectionCard(
                      'Security & Privacy',
                      Icons.security,
                      Colors.purple,
                      [
                        // _buildSwitchTile(
                        //   'Biometric Authentication',
                        //   'Use fingerprint or face unlock',
                        //   settings.biometricEnabled,
                        //   (value) =>
                        //       settingsNotifier.setBiometricEnabled(value),
                        // ),
                        // _buildSwitchTile(
                        //   'Data Backup',
                        //   'Backup app data to cloud',
                        //   settings.dataBackupEnabled,
                        //   (value) =>
                        //       settingsNotifier.setDataBackupEnabled(value),
                        // ),
                        _buildActionTile(
                          'Change Password',
                          'Update your account password',
                          () => _changePassword(),
                        ),
                        _buildActionTile(
                          'Privacy Policy',
                          'View our privacy policy',
                          () => _showPrivacyPolicy(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // App Settings
                    // _buildSectionCard(
                    //   'App Settings',
                    //   Icons.settings,
                    //   Colors.green,
                    //   [
                    //     _buildActionTile(
                    //       'About Nirbhay',
                    //       'App version and information',
                    //       () => _showAboutDialog(),
                    //     ),
                    //     _buildActionTile(
                    //       'Contact Support',
                    //       'Get help or report issues',
                    //       () => _contactSupport(),
                    //     ),
                    //     _buildActionTile(
                    //       'Rate App',
                    //       'Rate us on the app store',
                    //       () => _rateApp(),
                    //     ),
                    //     _buildActionTile(
                    //       'Export Data',
                    //       'Download your safety data',
                    //       () => _exportData(),
                    //     ),
                    //   ],
                    // ),
                    // const SizedBox(height: 20),

                    // Reset Settings
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange.shade600,
                            size: 32,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Reset Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Reset all settings to default values',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _resetSettings(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Reset to Defaults'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildSectionCard(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile(
    String title,
    String subtitle,
    String value,
    List<String> options,
    Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            items:
                options
                    .map(
                      (String option) => DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      ),
                    )
                    .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(String title, String subtitle, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  void _calibrateSensors() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Calibrating sensors...')));
  }

  void _syncDevice() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Syncing with device...')));
  }

  void _changePassword() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Change Password'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password updated successfully'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                child: const Text(
                  'Update',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Privacy Policy'),
            content: const SingleChildScrollView(
              child: Text(
                'Your privacy is important to us. This privacy policy explains how Nirbhay collects, uses, and protects your personal information...\n\nData Collection:\n• Location data for emergency services\n• Health metrics from wearable device\n• Emergency contact information\n\nData Usage:\n• Threat detection and safety monitoring\n• Emergency response coordination\n• App functionality improvements\n\nData Protection:\n• End-to-end encryption\n• Secure cloud storage\n• No data sharing with third parties',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('About Nirbhay'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Version: 1.0.0'),
                SizedBox(height: 8),
                Text('Build: 2024.06.15'),
                SizedBox(height: 16),
                Text(
                  'Nirbhay is a comprehensive safety companion app designed to protect young women through smart wearable technology and intelligent threat detection.',
                ),
                SizedBox(height: 16),
                Text('© 2024 Nirbhay Technologies'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _contactSupport() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Opening support chat...')));
  }

  void _rateApp() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Opening app store...')));
  }

  void _exportData() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Preparing data export...')));
  }

  void _resetSettings() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset Settings'),
            content: const Text(
              'Are you sure you want to reset all settings to default values? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  ref.read(settingsStateProvider.notifier).resetToDefaults();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings reset to defaults')),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text(
                  'Reset',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }
}
