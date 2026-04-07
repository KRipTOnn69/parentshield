import 'package:cloud_firestore/cloud_firestore.dart';

/// User model representing a parent account in ParentShield
class UserModel {
  final String uid;
  final String email;
  final String name;
  final String? hashedPin;
  final bool biometricEnabled;
  final bool hasPinSet;
  final List<String> childDeviceIds;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.hashedPin,
    this.biometricEnabled = false,
    this.hasPinSet = false,
    this.childDeviceIds = const [],
    required this.createdAt,
    this.updatedAt,
  });

  /// Create UserModel from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      name: data['name'] as String? ?? '',
      hashedPin: data['hashedPin'] as String?,
      biometricEnabled: data['biometricEnabled'] as bool? ?? false,
      hasPinSet: data['hasPinSet'] as bool? ?? false,
      childDeviceIds: List<String>.from(
        data['childDeviceIds'] as List<dynamic>? ?? [],
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Create UserModel from a Map and document ID
  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      uid: id,
      email: data['email'] as String? ?? '',
      name: data['name'] as String? ?? '',
      hashedPin: data['hashedPin'] as String?,
      biometricEnabled: data['biometricEnabled'] as bool? ?? false,
      hasPinSet: data['hasPinSet'] as bool? ?? false,
      childDeviceIds: List<String>.from(
        data['childDeviceIds'] as List<dynamic>? ?? [],
      ),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert UserModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'hashedPin': hashedPin,
      'biometricEnabled': biometricEnabled,
      'hasPinSet': hasPinSet,
      'childDeviceIds': childDeviceIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  /// Alias for toFirestore — returns model as a plain Map
  Map<String, dynamic> toMap() => toFirestore();

  /// Create a copy of this UserModel with optional field overrides
  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? hashedPin,
    bool? biometricEnabled,
    bool? hasPinSet,
    List<String>? childDeviceIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      hashedPin: hashedPin ?? this.hashedPin,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      hasPinSet: hasPinSet ?? this.hasPinSet,
      childDeviceIds: childDeviceIds ?? this.childDeviceIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Add a child device ID to the user
  UserModel addChildDevice(String deviceId) {
    if (childDeviceIds.contains(deviceId)) {
      return this;
    }
    return copyWith(
      childDeviceIds: [...childDeviceIds, deviceId],
    );
  }

  /// Remove a child device ID from the user
  UserModel removeChildDevice(String deviceId) {
    return copyWith(
      childDeviceIds: childDeviceIds
          .where((id) => id != deviceId)
          .toList(),
    );
  }

  /// Check if user has PIN configured
  bool hasPinConfigured() => hashedPin != null && hashedPin!.isNotEmpty;

  /// Check if user has biometric authentication enabled
  bool hasBiometricEnabled() => biometricEnabled && hasPinConfigured();

  @override
  String toString() => 'UserModel('
      'uid: $uid, '
      'email: $email, '
      'name: $name, '
      'hasPinSet: $hasPinSet, '
      'biometricEnabled: $biometricEnabled, '
      'childDeviceIds: ${childDeviceIds.length}'
      ')';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          email == other.email &&
          name == other.name &&
          hasPinSet == other.hasPinSet &&
          biometricEnabled == other.biometricEnabled &&
          childDeviceIds == other.childDeviceIds;

  @override
  int get hashCode =>
      uid.hashCode ^
      email.hashCode ^
      name.hashCode ^
      hasPinSet.hashCode ^
      biometricEnabled.hashCode ^
      childDeviceIds.hashCode;
}
