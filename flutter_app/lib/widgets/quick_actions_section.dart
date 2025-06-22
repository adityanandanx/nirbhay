import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import 'quick_action_card.dart';

class QuickActionsSection extends ConsumerWidget {
  const QuickActionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: QuickActionCard(
                title: 'Emergency\nAlert',
                icon: Icons.emergency,
                color: Colors.red,
                onTap: () => _showEmergencyDialog(context, ref),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: QuickActionCard(
                title: 'Share\nLocation',
                icon: Icons.location_on,
                color: Colors.orange,
                onTap: () => _shareLocation(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: QuickActionCard(
                title: 'Call\nSupport',
                icon: Icons.phone,
                color: Colors.blue,
                onTap: () => _callSupport(context),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: QuickActionCard(
                title: 'Safety\nTips',
                icon: Icons.lightbulb_outline,
                color: Colors.green,
                onTap: () => _showSafetyTips(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showEmergencyDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Emergency Alert'),
          content: const Text(
            'Are you sure you want to send an emergency alert to your contacts?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(safetyStateProvider.notifier).triggerEmergencyAlert();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Emergency alert sent!')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Send Alert',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _shareLocation(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location shared with emergency contacts')),
    );
  }

  Future<void> _callSupport(BuildContext context) async {
    const number = '8439336494'; // set the number here
    bool? res = await FlutterPhoneDirectCaller.callNumber(number);
    if (context.mounted && res == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Support call initiated')));
    }
  }

  void _showSafetyTips(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Safety Tips'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• Always keep your phone charged'),
              Text('• Share your location with trusted contacts'),
              Text('• Trust your instincts'),
              Text('• Stay in well-lit areas'),
              Text('• Keep emergency contacts updated'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }
}
