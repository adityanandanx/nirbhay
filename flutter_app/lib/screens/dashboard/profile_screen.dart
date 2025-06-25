import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // User data will come from Firebase Auth

  @override
  Widget build(BuildContext context) {
    // Get the current auth state
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    // User information
    final String displayName = user?.displayName ?? 'No Name Set';
    final String email = user?.email ?? 'No Email';
    final String joinDate =
        user?.metadata.creationTime != null
            ? _formatDate(user!.metadata.creationTime!)
            : 'Unknown';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _editProfile,
            icon: const Icon(Icons.edit, color: Colors.purple),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade400, Colors.purple.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  // Profile Picture
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.purple.shade400,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // User Name
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // User Email
                  Text(
                    email,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 4),

                  // Join Date
                  Text(
                    'Member since $joinDate',
                    style: const TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Profile Options
            _buildProfileOption(
              'Personal Information',
              Icons.person_outline,
              () => _showPersonalInfo(),
            ),
            const SizedBox(height: 12),

            _buildProfileOption(
              'Security Settings',
              Icons.security,
              () => _showSecuritySettings(),
            ),
            const SizedBox(height: 12),

            _buildProfileOption(
              'Wearable Device',
              Icons.watch,
              () => _showWearableSettings(),
            ),
            const SizedBox(height: 12),

            _buildProfileOption(
              'Emergency Settings',
              Icons.emergency,
              () => _showEmergencySettings(),
            ),
            const SizedBox(height: 12),

            _buildProfileOption(
              'Privacy & Data',
              Icons.privacy_tip_outlined,
              () => _showPrivacySettings(),
            ),
            const SizedBox(height: 12),

            _buildProfileOption(
              'Notifications',
              Icons.notifications_outlined,
              () => _showNotificationSettings(),
            ),
            const SizedBox(height: 12),

            _buildProfileOption(
              'Help & Support',
              Icons.help_outline,
              () => _showHelpSupport(),
            ),
            const SizedBox(height: 24),

            // Safety Stats
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Safety Stats',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard('Days Safe', '127', Colors.green),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard('Alerts Sent', '0', Colors.blue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard('Check-ins', '45', Colors.orange),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard('Contacts', '3', Colors.purple),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _logout,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.purple.shade600, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
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

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: color.withAlpha(80),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _editProfile() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Profile'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Phone',
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
                      content: Text('Profile updated successfully'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                child: const Text(
                  'Save',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _showPersonalInfo() {
    final authState = ref.read(authStateProvider);
    final user = authState.user;

    final String displayName = user?.displayName ?? 'No Name Set';
    final String email = user?.email ?? 'No Email';
    final String phone = user?.phoneNumber ?? 'No Phone Number';

    _showInfoDialog('Personal Information', [
      'Name: $displayName',
      'Email: $email',
      'Phone: $phone',
      'User ID: ${user?.uid ?? 'Unknown'}',
      'Email Verified: ${user?.emailVerified ?? false ? 'Yes' : 'No'}',
    ]);
  }

  void _showSecuritySettings() {
    _showInfoDialog('Security Settings', [
      '• Two-factor authentication',
      '• Emergency PIN setup',
      '• Biometric authentication',
      '• Password management',
      '• Account recovery options',
    ]);
  }

  void _showWearableSettings() {
    _showInfoDialog('Wearable Device', [
      'Device: Nirbhay Smart Bracelet',
      'Status: Connected',
      'Battery: 87%',
      'Last Sync: 2 minutes ago',
      'Firmware: v2.1.3',
    ]);
  }

  void _showEmergencySettings() {
    _showInfoDialog('Emergency Settings', [
      '• Auto-alert triggers',
      '• Emergency contact priority',
      '• Location sharing settings',
      '• Response time configuration',
      '• False alarm prevention',
    ]);
  }

  void _showPrivacySettings() {
    _showInfoDialog('Privacy & Data', [
      '• Data collection preferences',
      '• Location tracking settings',
      '• Analytics opt-out',
      '• Data export options',
      '• Account deletion',
    ]);
  }

  void _showNotificationSettings() {
    _showInfoDialog('Notification Settings', [
      '• Emergency alerts',
      '• Safety reminders',
      '• Device notifications',
      '• App updates',
      '• Marketing communications',
    ]);
  }

  void _showHelpSupport() {
    _showInfoDialog('Help & Support', [
      '• FAQ & Troubleshooting',
      '• Contact Support',
      '• Safety tutorials',
      '• Report a bug',
      '• Feature requests',
    ]);
  }

  void _showInfoDialog(String title, List<String> items) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    items
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(item),
                          ),
                        )
                        .toList(),
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

  void _logout() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Sign Out'),
            content: const Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();

                  try {
                    // Call the sign out method from the auth provider
                    await ref.read(authStateProvider.notifier).signOut();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Signed out successfully'),
                        ),
                      );

                      // The main.dart file is already set up to redirect to the login screen
                      // when auth state changes, so we don't need to navigate manually
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error signing out: ${e.toString()}'),
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  // Format date to readable format
  String _formatDate(DateTime dateTime) {
    // This would require the intl package
    // Use simple string formatting for now
    return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
  }
}
