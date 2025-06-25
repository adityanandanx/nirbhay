import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../providers/user_provider.dart';
import '../../widgets/location_map_section.dart';
import '../../widgets/quick_actions_section.dart';
import '../../widgets/safety_status_card.dart';
import '../../widgets/sos_button.dart';
import '../../widgets/triangle_of_safety_section.dart';
import '../../widgets/wearable_status_card.dart';
import '../ble_connection_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize BLE when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bleStateProvider.notifier).initialize();
    });
  }

  void _navigateToBLEConnection() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const BLEConnectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with greeting
              // User greeting with actual name
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Get user data from provider
                      Consumer(
                        builder: (context, ref, child) {
                          // Get the current user data
                          final userData = ref.watch(userDataProvider);

                          return userData.when(
                            loading:
                                () => Text(
                                  'Hello there',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                            error:
                                (_, __) => Text(
                                  'Hello there',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                            data: (userModel) {
                              // Get first name from full name
                              final fullName =
                                  userModel?.displayName ?? 'there';
                              final firstName = fullName.split(' ').first;

                              return Text(
                                'Hello, $firstName',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Stay safe, stay protected',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  // Notification bell
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.notifications_outlined,
                      color: Colors.grey.shade700,
                      size: 24,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),
              // Big SOS Button (only visible when safety mode is active)
              const SOSButton(),
              if (ref.watch(safetyStateProvider).isSafetyModeActive)
                const SizedBox(height: 30),
              // Safety Status Card
              const SafetyStatusCard(),
              const SizedBox(height: 30),

              // Wearable Status
              WearableStatusCard(onManageDevice: _navigateToBLEConnection),
              const SizedBox(height: 30),

              // Location Map Section (new addition)
              const LocationMapSection(),
              const SizedBox(height: 30),

              // Quick Actions
              const QuickActionsSection(),
              const SizedBox(height: 30),

              // Triangle of Safety Section
              const TriangleOfSafetySection(),
            ],
          ),
        ),
      ),
    );
  }
}
