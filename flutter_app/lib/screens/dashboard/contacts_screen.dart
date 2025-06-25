import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/emergency_contact.dart';
import '../../providers/app_providers.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    final safetyState = ref.watch(safetyStateProvider);
    final emergencyContacts = safetyState.emergencyContacts;
    final authState = ref.watch(authStateProvider);
    final isLoggedIn = authState.user != null;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Emergency Contacts',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _addNewContact,
            icon: const Icon(Icons.add, color: Colors.purple),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Firestore sync status
            if (isLoggedIn && emergencyContacts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_done,
                      size: 16,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isSyncing
                          ? 'Syncing contacts...'
                          : 'Contacts synced with cloud',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

            // Contacts List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Saved Contacts',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${emergencyContacts.where((c) => c.isActive).length} Active',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: ListView.builder(
                itemCount: emergencyContacts.length,
                itemBuilder: (context, index) {
                  final contact = emergencyContacts[index];
                  return _buildContactCard(contact, index, emergencyContacts);
                },
              ),
            ),

            // Add Contact Button
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _addNewContact,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text(
                  'Add Emergency Contact',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(
    EmergencyContact contact,
    int index,
    List<EmergencyContact> contacts,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _getContactColor(contact.relationship),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                contact.name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Contact Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contact.phone,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getContactColor(
                      contact.relationship,
                    ).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    contact.relationship,
                    style: TextStyle(
                      fontSize: 12,
                      color: _getContactColor(contact.relationship),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Status and Actions
          Column(
            children: [
              Switch(
                value: contact.isActive,
                onChanged: (value) {
                  final updatedContact = contact.copyWith(isActive: value);
                  ref
                      .read(safetyStateProvider.notifier)
                      .updateEmergencyContact(updatedContact);
                },
                activeColor: Colors.purple,
              ),
              PopupMenuButton(
                icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                itemBuilder:
                    (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'call',
                        child: Row(
                          children: [
                            Icon(Icons.phone, size: 18),
                            SizedBox(width: 8),
                            Text('Call'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                onSelected:
                    (value) =>
                        _handleContactAction(value.toString(), index, contacts),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getContactColor(String relationship) {
    switch (relationship.toLowerCase()) {
      case 'family':
        return Colors.purple;
      case 'friend':
        return Colors.blue;
      case 'colleague':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  void _handleContactAction(
    String action,
    int index,
    List<EmergencyContact> contacts,
  ) {
    switch (action) {
      case 'edit':
        _editContact(index, contacts);
        break;
      case 'call':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Calling ${contacts[index].name}...')),
        );
        break;
      case 'delete':
        _deleteContact(index, contacts);
        break;
    }
  }

  void _addNewContact() {
    _showContactDialog();
  }

  void _editContact(int index, List<EmergencyContact> contacts) {
    _showContactDialog(contact: contacts[index], index: index);
  }

  void _deleteContact(int index, List<EmergencyContact> contacts) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Contact'),
            content: Text(
              'Are you sure you want to delete ${contacts[index].name}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  setState(() => _isSyncing = true);
                  ref
                      .read(safetyStateProvider.notifier)
                      .removeEmergencyContact(contacts[index].id);
                  Navigator.of(context).pop();

                  // Delay to show syncing status
                  await Future.delayed(const Duration(seconds: 1));
                  if (mounted) setState(() => _isSyncing = false);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _showContactDialog({EmergencyContact? contact, int? index}) {
    final nameController = TextEditingController(text: contact?.name ?? '');
    final phoneController = TextEditingController(text: contact?.phone ?? '');
    String selectedRelationship = contact?.relationship ?? 'Family';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(contact == null ? 'Add Contact' : 'Edit Contact'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
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
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRelationship,
                    decoration: const InputDecoration(
                      labelText: 'Relationship',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        ['Family', 'Friend', 'Colleague', 'Other']
                            .map(
                              (String value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                    onChanged: (String? newValue) {
                      selectedRelationship = newValue!;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty &&
                      phoneController.text.isNotEmpty) {
                    if (index != null) {
                      // Update existing contact
                      setState(() => _isSyncing = true);
                      final updatedContact = contact!.copyWith(
                        name: nameController.text,
                        phone: phoneController.text,
                        relationship: selectedRelationship,
                      );
                      ref
                          .read(safetyStateProvider.notifier)
                          .updateEmergencyContact(updatedContact);

                      // Delay to show syncing status
                      await Future.delayed(const Duration(seconds: 1));
                      if (mounted) setState(() => _isSyncing = false);
                    } else {
                      // Add new contact
                      setState(() => _isSyncing = true);
                      final newContact = EmergencyContact(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameController.text,
                        phone: phoneController.text,
                        relationship: selectedRelationship,
                        isActive: true,
                        priority:
                            (ref
                                    .read(safetyStateProvider)
                                    .emergencyContacts
                                    .length +
                                1),
                      );
                      ref
                          .read(safetyStateProvider.notifier)
                          .addEmergencyContact(newContact);

                      // Delay to show syncing status
                      await Future.delayed(const Duration(seconds: 1));
                      if (mounted) setState(() => _isSyncing = false);
                    }
                    Navigator.of(context).pop();
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                child: Text(
                  contact == null ? 'Add' : 'Save',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }
}
