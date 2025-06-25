import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/fullscreen_map_view.dart';
import '../../widgets/online_status_indicator.dart';
import '../../widgets/online_users_widget.dart';
import '../../providers/location_tracking_provider.dart';

/// Provider to track whether we're showing all users or only online users
final _showAllUsersProvider = StateProvider<bool>((ref) => false);

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(locationTrackingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Map'),
        elevation: 0,
        actions: [
          // Online users button
          IconButton(
            icon: const Icon(Icons.people_outline),
            onPressed: () {
              _showOnlineUsers(context);
            },
          ),
          // Information button to show details about location sharing
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showLocationSharingInfo(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Live tracking status banner (only shows when actively sharing)
          if (locationState.isSharingLocation)
            Container(
              color: Colors.green.shade100,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.sync, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Live location sharing is active',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            // Show online status indicator
                            const OnlineStatusIndicator(
                              size: 8,
                              showText: false,
                            ),
                          ],
                        ),
                        Text(
                          'Your location is being securely shared with Firebase in real-time',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ref
                          .read(locationTrackingProvider.notifier)
                          .toggleLocationSharing();
                    },
                    child: const Text('STOP'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ),

          // Expanded map section that takes most of the screen
          const Expanded(child: FullscreenMapView()),
        ],
      ),
    );
  }

  void _showLocationSharingInfo(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Real-time Location Sharing'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This feature shares your location to Firebase Realtime Database as you move.',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                Text(
                  'When enabled:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Your location updates every 10 meters'),
                Text('• Data is stored securely on Firebase'),
                Text('• Your online status is visible to others'),
                Text('• Battery usage increases'),
                SizedBox(height: 16),
                Text(
                  'Current Status:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                // Show the online status indicator with text
                const OnlineStatusIndicator(size: 12),
                SizedBox(height: 16),
                Text(
                  'Toggle location sharing using the location button on the map.',
                  style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CLOSE'),
              ),
            ],
          ),
    );
  }

  void _showOnlineUsers(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.2,
            maxChildSize: 0.8,
            builder:
                (context, scrollController) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    children: [
                      // Handle
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Title
                      const Text(
                        'Online Users',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Switch for showing all users vs online only
                      Consumer(
                        builder: (context, ref, _) {
                          final showAllUsers = ref.watch(_showAllUsersProvider);
                          return SwitchListTile(
                            title: const Text('Show all users'),
                            value: showAllUsers,
                            onChanged: (value) {
                              ref.read(_showAllUsersProvider.notifier).state =
                                  value;
                            },
                          );
                        },
                      ),
                      const Divider(),
                      // List of users
                      Expanded(
                        child: Consumer(
                          builder: (context, ref, _) {
                            final showAllUsers = ref.watch(
                              _showAllUsersProvider,
                            );
                            return OnlineUsersWidget(
                              showAllUsers: showAllUsers,
                              onUserTap: (userId) {
                                // In the future, this could center the map on this user
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Selected user: $userId'),
                                  ),
                                );
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }
}
