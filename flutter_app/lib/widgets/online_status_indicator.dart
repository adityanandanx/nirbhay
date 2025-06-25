import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';

class OnlineStatusIndicator extends ConsumerWidget {
  final String? userId;
  final double size;
  final bool showText;
  final bool showOffline;

  const OnlineStatusIndicator({
    super.key,
    this.userId, // If null, shows current user's status
    this.size = 10.0,
    this.showText = true,
    this.showOffline = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebaseLocationService = ref.watch(firebaseLocationServiceProvider);

    return StreamBuilder<bool>(
      stream:
          userId != null
              ? firebaseLocationService.getUserOnlineStatus(userId!)
              : firebaseLocationService.getCurrentUserOnlineStatus(),
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? false;

        // If offline and configured not to show offline status, return empty container
        if (!isOnline && !showOffline) {
          return const SizedBox.shrink();
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: isOnline ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            if (showText) ...[
              const SizedBox(width: 6),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: size * 1.2,
                  fontWeight: FontWeight.w500,
                  color:
                      isOnline ? Colors.green.shade700 : Colors.grey.shade700,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
