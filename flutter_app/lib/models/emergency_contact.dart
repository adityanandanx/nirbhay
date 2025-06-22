class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String relationship;
  final bool isActive;
  final int priority; // Lower number = higher priority (1 is highest)

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relationship,
    this.isActive = true,
    this.priority = 1,
  });

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phone,
    String? relationship,
    bool? isActive,
    int? priority,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
      isActive: isActive ?? this.isActive,
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'isActive': isActive,
      'priority': priority,
    };
  }

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      relationship: json['relationship'] ?? '',
      isActive: json['isActive'] ?? true,
      priority: json['priority'] ?? 1,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmergencyContact &&
        other.id == id &&
        other.name == name &&
        other.phone == phone &&
        other.relationship == relationship &&
        other.isActive == isActive &&
        other.priority == priority;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, phone, relationship, isActive, priority);
  }

  @override
  String toString() {
    return 'EmergencyContact(id: $id, name: $name, phone: $phone, relationship: $relationship, isActive: $isActive, priority: $priority)';
  }
}
