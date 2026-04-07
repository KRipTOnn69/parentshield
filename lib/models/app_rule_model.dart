import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a time schedule for app restrictions
class TimeSchedule {
  final String startTime; // HH:mm format
  final String endTime; // HH:mm format
  final List<int> activeDays; // 0 = Monday, 6 = Sunday

  TimeSchedule({
    required this.startTime,
    required this.endTime,
    this.activeDays = const [0, 1, 2, 3, 4, 5, 6], // All days by default
  });

  factory TimeSchedule.fromMap(Map<String, dynamic> map) {
    return TimeSchedule(
      startTime: map['startTime'] as String? ?? '00:00',
      endTime: map['endTime'] as String? ?? '23:59',
      activeDays: List<int>.from(
        map['activeDays'] as List<dynamic>? ?? [0, 1, 2, 3, 4, 5, 6],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startTime': startTime,
      'endTime': endTime,
      'activeDays': activeDays,
    };
  }

  /// Check if the app is currently blocked based on schedule
  bool isCurrentlyBlocked() {
    final now = DateTime.now();
    final currentDay = now.weekday == 7 ? 6 : now.weekday - 1; // Convert to 0-6

    // Check if today is an active day
    if (!activeDays.contains(currentDay)) {
      return false;
    }

    // Parse schedule times
    final startParts = startTime.split(':');
    final endParts = endTime.split(':');

    final startMinutes =
        int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    final currentMinutes = now.hour * 60 + now.minute;

    return currentMinutes >= startMinutes && currentMinutes < endMinutes;
  }

  TimeSchedule copyWith({
    String? startTime,
    String? endTime,
    List<int>? activeDays,
  }) {
    return TimeSchedule(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      activeDays: activeDays ?? this.activeDays,
    );
  }

  @override
  String toString() =>
      'TimeSchedule($startTime - $endTime, days: ${activeDays.length})';
}

/// Model representing app blocking and usage rules
class AppRule {
  final String packageName;
  final String appName;
  final bool isBlocked;
  final int? dailyLimitMinutes;
  final TimeSchedule? schedule;
  final int usedTodayMinutes;

  AppRule({
    required this.packageName,
    required this.appName,
    this.isBlocked = false,
    this.dailyLimitMinutes,
    this.schedule,
    this.usedTodayMinutes = 0,
  });

  factory AppRule.fromMap(Map<String, dynamic> map) {
    return AppRule(
      packageName: map['packageName'] as String? ?? '',
      appName: map['appName'] as String? ?? '',
      isBlocked: map['isBlocked'] as bool? ?? false,
      dailyLimitMinutes: map['dailyLimitMinutes'] as int?,
      schedule: map['schedule'] != null
          ? TimeSchedule.fromMap(map['schedule'] as Map<String, dynamic>)
          : null,
      usedTodayMinutes: map['usedTodayMinutes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'packageName': packageName,
      'appName': appName,
      'isBlocked': isBlocked,
      'dailyLimitMinutes': dailyLimitMinutes,
      'schedule': schedule?.toMap(),
      'usedTodayMinutes': usedTodayMinutes,
    };
  }

  /// Check if app has a time limit configured
  bool hasTimeLimit() => dailyLimitMinutes != null && dailyLimitMinutes! > 0;

  /// Check if daily time limit has been reached
  bool isTimeLimitReached() {
    if (!hasTimeLimit()) return false;
    return usedTodayMinutes >= dailyLimitMinutes!;
  }

  /// Get usage percentage (0-100)
  int usagePercentage() {
    if (!hasTimeLimit()) return 0;
    final percentage = (usedTodayMinutes / dailyLimitMinutes!) * 100;
    return percentage.ceil().clamp(0, 100);
  }

  /// Get remaining minutes for the day
  int remainingMinutes() {
    if (!hasTimeLimit()) return 0;
    final remaining = dailyLimitMinutes! - usedTodayMinutes;
    return remaining > 0 ? remaining : 0;
  }

  /// Check if app should be blocked (time limit reached or scheduled block)
  bool shouldBeBlocked() {
    if (isBlocked) return true;
    if (isTimeLimitReached()) return true;
    if (schedule?.isCurrentlyBlocked() ?? false) return true;
    return false;
  }

  AppRule copyWith({
    String? packageName,
    String? appName,
    bool? isBlocked,
    int? dailyLimitMinutes,
    TimeSchedule? schedule,
    int? usedTodayMinutes,
  }) {
    return AppRule(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      isBlocked: isBlocked ?? this.isBlocked,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      schedule: schedule ?? this.schedule,
      usedTodayMinutes: usedTodayMinutes ?? this.usedTodayMinutes,
    );
  }

  @override
  String toString() =>
      'AppRule(package: $packageName, blocked: $isBlocked, used: ${usedTodayMinutes}min)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppRule &&
          runtimeType == other.runtimeType &&
          packageName == other.packageName;

  @override
  int get hashCode => packageName.hashCode;
}

/// Model representing web filter rules
class WebFilterRule {
  final List<String> blockedCategories;
  final List<String> customBlocklist; // URLs/domains to block
  final List<String> customAllowlist; // URLs/domains to allow
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime? updatedAt;

  WebFilterRule({
    this.blockedCategories = const [],
    this.customBlocklist = const [],
    this.customAllowlist = const [],
    this.isEnabled = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory WebFilterRule.fromMap(Map<String, dynamic> map) {
    return WebFilterRule(
      blockedCategories: List<String>.from(
        map['blockedCategories'] as List<dynamic>? ?? [],
      ),
      customBlocklist: List<String>.from(
        map['customBlocklist'] as List<dynamic>? ?? [],
      ),
      customAllowlist: List<String>.from(
        map['customAllowlist'] as List<dynamic>? ?? [],
      ),
      isEnabled: map['isEnabled'] as bool? ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'blockedCategories': blockedCategories,
      'customBlocklist': customBlocklist,
      'customAllowlist': customAllowlist,
      'isEnabled': isEnabled,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  /// Check if a URL should be blocked
  bool shouldBlockUrl(String url) {
    if (!isEnabled) return false;

    // Check custom allowlist first (whitelist takes precedence)
    for (final allowed in customAllowlist) {
      if (url.contains(allowed)) {
        return false;
      }
    }

    // Check custom blocklist
    for (final blocked in customBlocklist) {
      if (url.contains(blocked)) {
        return true;
      }
    }

    return false;
  }

  WebFilterRule copyWith({
    List<String>? blockedCategories,
    List<String>? customBlocklist,
    List<String>? customAllowlist,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WebFilterRule(
      blockedCategories: blockedCategories ?? this.blockedCategories,
      customBlocklist: customBlocklist ?? this.customBlocklist,
      customAllowlist: customAllowlist ?? this.customAllowlist,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Add a category to blocked list
  WebFilterRule addBlockedCategory(String category) {
    if (blockedCategories.contains(category)) return this;
    return copyWith(
      blockedCategories: [...blockedCategories, category],
    );
  }

  /// Remove a category from blocked list
  WebFilterRule removeBlockedCategory(String category) {
    return copyWith(
      blockedCategories:
          blockedCategories.where((c) => c != category).toList(),
    );
  }

  /// Add a URL to custom blocklist
  WebFilterRule addCustomBlockedUrl(String url) {
    if (customBlocklist.contains(url)) return this;
    return copyWith(
      customBlocklist: [...customBlocklist, url],
    );
  }

  /// Remove a URL from custom blocklist
  WebFilterRule removeCustomBlockedUrl(String url) {
    return copyWith(
      customBlocklist: customBlocklist.where((u) => u != url).toList(),
    );
  }

  @override
  String toString() =>
      'WebFilterRule(enabled: $isEnabled, blocked: ${blockedCategories.length}, custom: ${customBlocklist.length})';
}
