class UserModel {
  final String id;
  final String email;
  final String? displayName;
  final String? phoneNumber;
  final String? photoURL;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? additionalData;

  UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.phoneNumber,
    this.photoURL,
    this.createdAt,
    this.updatedAt,
    this.additionalData,
  });

  // Create UserModel from Firebase User
  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserModel(
      id: id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      phoneNumber: data['phoneNumber'],
      photoURL: data['photoURL'],
      createdAt: data['createdAt']?.toDate(),
      updatedAt: data['updatedAt']?.toDate(),
      additionalData: Map.from(data)..removeWhere(
        (key, value) => [
          'email',
          'displayName',
          'phoneNumber',
          'photoURL',
          'createdAt',
          'updatedAt',
        ].contains(key),
      ),
    );
  }

  // Convert UserModel to Map
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName ?? '',
      'phoneNumber': phoneNumber ?? '',
      'photoURL': photoURL ?? '',
      if (additionalData != null) ...additionalData!,
    };
  }

  // Create a copy of the UserModel with updated fields
  UserModel copyWith({
    String? email,
    String? displayName,
    String? phoneNumber,
    String? photoURL,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? additionalData,
  }) {
    return UserModel(
      id: this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      additionalData: additionalData ?? this.additionalData,
    );
  }
}
