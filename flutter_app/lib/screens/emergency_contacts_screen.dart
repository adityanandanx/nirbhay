import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/emergency_contact.dart';
import '../providers/app_providers.dart';
import '../providers/safety_provider.dart';

class EmergencyContactsScreen extends ConsumerWidget {
  const EmergencyContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safetyState = ref.watch(safetyStateProvider);
    final safetyNotifier = ref.watch(safetyStateProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        backgroundColor: Colors.red.shade50,
        foregroundColor: Colors.red.shade800,
      ),
      body: Column(
        children: [
          // Status Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  safetyState.isSafetyModeActive
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
              border: Border.all(
                color:
                    safetyState.isSafetyModeActive
                        ? Colors.green
                        : Colors.orange,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  safetyState.isSafetyModeActive ? Icons.shield : Icons.warning,
                  color:
                      safetyState.isSafetyModeActive
                          ? Colors.green
                          : Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safety Status: ${safetyState.safetyStatus}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (safetyState.currentLocation != null)
                        Text(
                          'Location: ${safetyState.currentLocation!.latitude.toStringAsFixed(4)}, ${safetyState.currentLocation!.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Emergency Contacts List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: safetyState.emergencyContacts.length,
              itemBuilder: (context, index) {
                final contact = safetyState.emergencyContacts[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(contact.name),
                    subtitle: Text(
                      '${contact.phone} • ${contact.relationship}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed:
                          () =>
                              safetyNotifier.removeEmergencyContact(contact.id),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed:
            () => _showAddContactDialog(
              context,
              safetyNotifier,
              safetyState.emergencyContacts.length,
            ),
        backgroundColor: Colors.red,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddContactDialog(
    BuildContext context,
    SafetyStateNotifier notifier,
    int currentContactCount,
  ) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Emergency Contact'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty &&
                      phoneController.text.isNotEmpty) {
                    final newContact = EmergencyContact(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameController.text,
                      phone: phoneController.text,
                      relationship: 'Other',
                      isActive: true,
                      priority: currentContactCount + 1,
                    );
                    notifier.addEmergencyContact(newContact);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }
}
