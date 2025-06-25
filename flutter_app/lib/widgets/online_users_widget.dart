import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import 'online_status_indicator.dart';

class OnlineUsersWidget extends ConsumerWidget {
  final bool showAllUsers; // If false, only shows online users
  final void Function(String userId)? onUserTap;

  const OnlineUsersWidget({
    super.key,
    this.showAllUsers = false,
    this.onUserTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebaseLocationService = ref.watch(firebaseLocationServiceProvider);

    return StreamBuilder<Map<String, Map<String, dynamic>>>(
      stream: firebaseLocationService.getAllUsersLocationsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No users found'));
        }

        final users = snapshot.data!;
        final onlineUsers =
            users.entries
                .where(
                  (entry) => showAllUsers || (entry.value['online'] == true),
                )
                .toList();

        if (onlineUsers.isEmpty) {
          return const Center(child: Text('No online users'));
        }

        return ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: onlineUsers.length,
          itemBuilder: (context, index) {
            final entry = onlineUsers[index];
            final userId = entry.key;
            final userData = entry.value;
            final isOnline = userData['online'] == true;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    isOnline ? Colors.green.shade100 : Colors.grey.shade200,
                child: Icon(
                  Icons.person,
                  color: isOnline ? Colors.green : Colors.grey,
                ),
              ),
              title: Row(
                children: [
                  Text('User ${userId.substring(0, 6)}...'),
                  const SizedBox(width: 8),
                  OnlineStatusIndicator(
                    userId: userId,
                    size: 8,
                    showText: false,
                  ),
                ],
              ),
              subtitle: Text(
                'Last updated: ${userData['lastUpdated'] ?? 'Unknown'}',
                style: TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing:
                  isOnline
                      ? const Icon(Icons.location_on, color: Colors.green)
                      : const Icon(Icons.location_off, color: Colors.grey),
              onTap: onUserTap != null ? () => onUserTap!(userId) : null,
            );
          },
        );
      },
    );
  }
}
