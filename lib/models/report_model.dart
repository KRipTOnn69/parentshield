import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Model representing a blocked app attempt
class BlockedAttempt {
  final String packageName;
  final String appName;
  final DateTime timestamp;
  final String reason; // 'time_limit_reached', 'schedule_blocked', 'app_blocked'

  BlockedAttempt({
    required this.packageName,
    required this.appName,
    required this.timestamp,
    required this.reason,
  });

  factory BlockedAttempt.fromMap(Map<String, dynamic> map) {
    return BlockedAttempt(
      packageName: map['packageName'] as String? ?? '',
      appName: map['appName'] as String? ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reason: map['reason'] as String? ?? 'unknown',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'packageName': packageName,
      'appName': appName,
      'timestamp': Timestamp.fromDate(timestamp),
      'reason': reason,
    };
  }

  @override
  String toString() =>
      'BlockedAttempt($appName at ${timestamp.toString()}, reason: $reason)';
}

/// Model representing a location history entry
class LocationEntry {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String? address;

  LocationEntry({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.address,
  });

  factory LocationEntry.fromMap(Map<String, dynamic> map) {
    return LocationEntry(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      address: map['address'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': Timestamp.fromDate(timestamp),
      'address': address,
    };
  }

  @override
  String toString() =>
      'LocationEntry(lat: $latitude, lng: $longitude, address: $address)';
}

/// Model representing daily app usage statistics
class DailyReport {
  final DateTime date;
  final int totalScreenTimeMinutes;
  final Map<String, int> appUsage; // packageName -> minutes
  final List<BlockedAttempt> blockedAttempts;
  final List<LocationEntry> locationHistory;

  DailyReport({
    required this.date,
    this.totalScreenTimeMinutes = 0,
    this.appUsage = const {},
    this.blockedAttempts = const [],
    this.locationHistory = const [],
  });

  /// Create DailyReport from Firestore document
  factory DailyReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DailyReport(
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalScreenTimeMinutes: data['totalScreenTimeMinutes'] as int? ?? 0,
      appUsage: Map<String, int>.from(
        (data['appUsage'] as Map<dynamic, dynamic>?) ?? {},
      ),
      blockedAttempts: (data['blockedAttempts'] as List<dynamic>?)
              ?.map((item) => BlockedAttempt.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      locationHistory: (data['locationHistory'] as List<dynamic>?)
              ?.map((item) => LocationEntry.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Convert DailyReport to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'totalScreenTimeMinutes': totalScreenTimeMinutes,
      'appUsage': appUsage,
      'blockedAttempts': blockedAttempts.map((a) => a.toMap()).toList(),
      'locationHistory': locationHistory.map((l) => l.toMap()).toList(),
    };
  }

  /// Get top apps by usage time
  List<MapEntry<String, int>> topApps({int limit = 5}) {
    final entries = appUsage.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }

  /// Get formatted screen time string
  String formattedScreenTime() {
    final hours = totalScreenTimeMinutes ~/ 60;
    final minutes = totalScreenTimeMinutes % 60;
    if (hours == 0) {
      return '${minutes}m';
    } else if (minutes == 0) {
      return '${hours}h';
    } else {
      return '${hours}h ${minutes}m';
    }
  }

  /// Get total blocked attempts count
  int get totalBlockedAttempts => blockedAttempts.length;

  /// Get number of unique apps used
  int get uniqueAppsUsed => appUsage.length;

  /// Get percentage change in screen time (compared to previous day's total)
  double screenTimePercentageChange(int previousDayTotal) {
    if (previousDayTotal == 0) return 0;
    return ((totalScreenTimeMinutes - previousDayTotal) / previousDayTotal) * 100;
  }

  /// Get formatted date
  String formattedDate() {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  /// Check if this is today
  bool isToday() {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Create a copy with updated values
  DailyReport copyWith({
    DateTime? date,
    int? totalScreenTimeMinutes,
    Map<String, int>? appUsage,
    List<BlockedAttempt>? blockedAttempts,
    List<LocationEntry>? locationHistory,
  }) {
    return DailyReport(
      date: date ?? this.date,
      totalScreenTimeMinutes: totalScreenTimeMinutes ?? this.totalScreenTimeMinutes,
      appUsage: appUsage ?? this.appUsage,
      blockedAttempts: blockedAttempts ?? this.blockedAttempts,
      locationHistory: locationHistory ?? this.locationHistory,
    );
  }

  /// Add app usage time
  DailyReport addAppUsage(String packageName, int minutes) {
    final updated = Map<String, int>.from(appUsage);
    updated[packageName] = (updated[packageName] ?? 0) + minutes;
    return copyWith(
      appUsage: updated,
      totalScreenTimeMinutes: totalScreenTimeMinutes + minutes,
    );
  }

  /// Add blocked attempt
  DailyReport addBlockedAttempt(BlockedAttempt attempt) {
    return copyWith(
      blockedAttempts: [...blockedAttempts, attempt],
    );
  }

  /// Add location entry
  DailyReport addLocationEntry(LocationEntry location) {
    return copyWith(
      locationHistory: [...locationHistory, location],
    );
  }

  @override
  String toString() =>
      'DailyReport(date: ${formattedDate()}, screenTime: ${formattedScreenTime()}, apps: $uniqueAppsUsed)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyReport &&
          runtimeType == other.runtimeType &&
          date.year == (other.date.year) &&
          date.month == (other.date.month) &&
          date.day == (other.date.day);

  @override
  int get hashCode => date.hashCode;
}
