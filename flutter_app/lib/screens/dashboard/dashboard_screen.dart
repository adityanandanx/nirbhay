import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nirbhay_flutter/widgets/emergency_countdown_overlay.dart';
import 'package:nirbhay_flutter/widgets/sos_floating_action_button.dart';
import 'package:nirbhay_flutter/providers/app_providers.dart';
import 'home_screen.dart';
import 'contacts_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;
  OverlayEntry? _overlayEntry;

  final List<Widget> _screens = const [
    HomeScreen(),
    MapScreen(),
    ContactsScreen(),
    ProfileScreen(),
    SettingsScreen(),
  ];

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showCountdownOverlay() {
    _removeOverlay();
    
    _overlayEntry = OverlayEntry(
      builder: (context) => const EmergencyCountdownOverlay(),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    // Watch safety state for countdown
    final safetyState = ref.watch(safetyStateProvider);
    
    // Show or hide overlay based on countdown state
    if (safetyState.isEmergencyCountdownActive && _overlayEntry == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCountdownOverlay();
      });
    } else if (!safetyState.isEmergencyCountdownActive && _overlayEntry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _removeOverlay();
      });
    }

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.contacts_outlined),
            selectedIcon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: const SOSFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
