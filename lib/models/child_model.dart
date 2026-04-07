import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parentshield/config/constants.dart';

/// Model representing a child's device location
class ChildLocation {
  final double latitude;
  final double longitude;
  final String? address;
  final DateTime timestamp;

  ChildLocation({
    required this.latitude,
    required this.longitude,
    this.address,
    required this.timestamp,
  });

  factory ChildLocation.fromMap(Map<String, dynamic> map) {
    return ChildLocation(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      address: map['address'] as String?,
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  @override
  String toString() =>
      'ChildLocation(lat: $latitude, lng: $longitude, address: $address)';
}

/// Model representing screen time rules for a child
class ScreenTimeRules {
  final int dailyLimitMinutes;
  final bool isEnabled;
  final Map<String, int> perAppLimits; // packageName -> minutes

  ScreenTimeRules({
    this.dailyLimitMinutes = AppConstants.defaultDailyLimitMinutes,
    this.isEnabled = true,
    this.perAppLimits = const {},
  });

  factory ScreenTimeRules.fromMap(Map<String, dynamic> map) {
    return ScreenTimeRules(
      dailyLimitMinutes:
          map['dailyLimitMinutes'] as int? ?? AppConstants.defaultDailyLimitMinutes,
      isEnabled: map['isEnabled'] as bool? ?? true,
      perAppLimits: Map<String, int>.from(
        (map['perAppLimits'] as Map<dynamic, dynamic>?) ?? {},
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dailyLimitMinutes': dailyLimitMinutes,
      'isEnabled': isEnabled,
      'perAppLimits': perAppLimits,
    };
  }

  ScreenTimeRules copyWith({
    int? dailyLimitMinutes,
    bool? isEnabled,
    Map<String, int>? perAppLimits,
  }) {
    return ScreenTimeRules(
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      isEnabled: isEnabled ?? this.isEnabled,
      perAppLimits: perAppLimits ?? this.perAppLimits,
    );
  }

  @override
  String toString() =>
      'ScreenTimeRules(dailyLimit: ${dailyLimitMinutes}min, enabled: $isEnabled)';
}

/// Model representing a child's device
class ChildDevice {
  final String deviceId;
  final String parentId;
  final String deviceName;
  final String pairingCode;
  final bool isActive;
  final ChildLocation? lastLocation;
  final ScreenTimeRules screenTimeRules;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ChildDevice({
    required this.deviceId,
    required this.parentId,
    required this.deviceName,
    required this.pairingCode,
    this.isActive = false,
    this.lastLocation,
    ScreenTimeRules? screenTimeRules,
    required this.createdAt,
    this.updatedAt,
  }) : screenTimeRules = screenTimeRules ?? ScreenTimeRules();

  /// Create ChildDevice from Firestore document
  factory ChildDevice.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChildDevice(
      deviceId: doc.id,
      parentId: data['parentId'] as String? ?? '',
      deviceName: data['deviceName'] as String? ?? 'Child Device',
      pairingCode: data['pairingCode'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? false,
      lastLocation: data['lastLocation'] != null
          ? ChildLocation.fromMap(data['lastLocation'] as Map<String, dynamic>)
          : null,
      screenTimeRules: data['screenTimeRules'] != null
          ? ScreenTimeRules.fromMap(
              data['screenTimeRules'] as Map<String, dynamic>)
          : ScreenTimeRules(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert ChildDevice to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'parentId': parentId,
      'deviceName': deviceName,
      'pairingCode': pairingCode,
      'isActive': isActive,
      'lastLocation': lastLocation?.toMap(),
      'screenTimeRules': screenTimeRules.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  /// Create a copy of this ChildDevice with optional field overrides
  ChildDevice copyWith({
    String? deviceId,
    String? parentId,
    String? deviceName,
    String? pairingCode,
    bool? isActive,
    ChildLocation? lastLocation,
    ScreenTimeRules? screenTimeRules,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChildDevice(
      deviceId: deviceId ?? this.deviceId,
      parentId: parentId ?? this.parentId,
      deviceName: deviceName ?? this.deviceName,
      pairingCode: pairingCode ?? this.pairingCode,
      isActive: isActive ?? this.isActive,
      lastLocation: lastLocation ?? this.lastLocation,
      screenTimeRules: screenTimeRules ?? this.screenTimeRules,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Update the device's location
  ChildDevice updateLocation(ChildLocation location) {
    return copyWith(lastLocation: location);
  }

  /// Update screen time rules
  ChildDevice updateScreenTimeRules(ScreenTimeRules rules) {
    return copyWith(screenTimeRules: rules);
  }

  /// Mark device as active
  ChildDevice activate() {
    return copyWith(isActive: true);
  }

  /// Mark device as inactive
  ChildDevice deactivate() {
    return copyWith(isActive: false);
  }

  @override
  String toString() =>
      'ChildDevice(deviceId: $deviceId, name: $deviceName, active: $isActive)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChildDevice &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          parentId == other.parentId &&
          isActive == other.isActive;

  @override
  int get hashCode => deviceId.hashCode ^ parentId.hashCode ^ isActive.hashCode;
}
