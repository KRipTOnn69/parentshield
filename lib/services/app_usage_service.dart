import 'package:app_usage/app_usage.dart';
import 'package:parentshield/models/app_rule_model.dart';

class AppInfo {
  final String packageName;
  final String appName;
  final String? appIcon;
  final int installTime;

  AppInfo({
    required this.packageName,
    required this.appName,
    this.appIcon,
    required this.installTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'packageName': packageName,
      'appName': appName,
      'appIcon': appIcon,
      'installTime': installTime,
    };
  }

  factory AppInfo.fromMap(Map<String, dynamic> map) {
    return AppInfo(
      packageName: map['packageName'] ?? '',
      appName: map['appName'] ?? '',
      appIcon: map['appIcon'],
      installTime: map['installTime'] ?? 0,
    );
  }
}

class AppUsageService {
  static final AppUsageService _instance = AppUsageService._internal();

  factory AppUsageService() {
    return _instance;
  }

  AppUsageService._internal();

  // ======================= APP RETRIEVAL =======================

  /// Get list of installed apps
  Future<List<AppInfo>> getInstalledApps() async {
    try {
      final apps = <AppInfo>[];

      // Note: getAppList() requires platform-specific implementation
      // This is a framework method that needs native code support
      // In production, implement native bridge or use device_apps package

      return apps;
    } catch (e) {
      throw Exception('Failed to get installed apps: ${e.toString()}');
    }
  }

  // ======================= SCREEN TIME OPERATIONS =======================

  /// Get daily screen time in minutes
  Future<int> getDailyScreenTime() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final stats = await AppUsage().getAppUsage(startOfDay, now);

      int totalMinutes = 0;
      for (final appUsage in stats) {
        final duration = appUsage.usage.inMinutes;
        totalMinutes += duration;
      }

      return totalMinutes;
    } on AppUsageException catch (e) {
      throw Exception('App usage permission required: ${e.toString()}');
    } catch (e) {
      throw Exception('Failed to get daily screen time: ${e.toString()}');
    }
  }

  /// Get app usage statistics for date range
  Future<Map<String, int>> getAppUsageStats(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      if (startDate.isAfter(endDate)) {
        throw Exception('Start date must be before end date');
      }

      if (endDate.isAfter(DateTime.now())) {
        throw Exception('End date cannot be in the future');
      }

      final stats = await AppUsage().getAppUsage(startDate, endDate);

      final usageMap = <String, int>{};
      for (final appUsage in stats) {
        final minutes = appUsage.usage.inMinutes;
        usageMap[appUsage.packageName] = minutes;
      }

      return usageMap;
    } on AppUsageException catch (e) {
      throw Exception('App usage permission required: ${e.toString()}');
    } catch (e) {
      throw Exception('Failed to get app usage stats: ${e.toString()}');
    }
  }

  // ======================= APP BLOCKING =======================

  /// Check if app should be blocked based on rules
  bool isAppBlocked(String packageName, List<AppRule> rules) {
    try {
      if (packageName.isEmpty) {
        throw Exception('Package name cannot be empty');
      }

      if (rules.isEmpty) {
        return false;
      }

      for (final rule in rules) {
        if (rule.packageName == packageName && rule.isBlocked) {
          return true;
        }
      }

      return false;
    } catch (e) {
      throw Exception('App blocking check failed: ${e.toString()}');
    }
  }

  /// Check if app is time-limited
  bool isAppTimeLimited(String packageName, List<AppRule> rules) {
    try {
      if (packageName.isEmpty) {
        throw Exception('Package name cannot be empty');
      }

      for (final rule in rules) {
        if (rule.packageName == packageName &&
            rule.dailyLimitMinutes != null &&
            rule.dailyLimitMinutes! > 0) {
          return true;
        }
      }

      return false;
    } catch (e) {
      throw Exception('Time limit check failed: ${e.toString()}');
    }
  }

  /// Get time limit for app
  int? getAppTimeLimit(String packageName, List<AppRule> rules) {
    try {
      for (final rule in rules) {
        if (rule.packageName == packageName) {
          return rule.dailyLimitMinutes;
        }
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get app time limit: ${e.toString()}');
    }
  }

  // ======================= SCREEN TIME CALCULATIONS =======================

  /// Get remaining screen time
  int getRemainingScreenTime(int dailyLimitMinutes, int usedMinutes) {
    try {
      if (dailyLimitMinutes < 0 || usedMinutes < 0) {
        throw Exception('Time values cannot be negative');
      }

      if (usedMinutes >= dailyLimitMinutes) {
        return 0;
      }

      return dailyLimitMinutes - usedMinutes;
    } catch (e) {
      throw Exception('Failed to calculate remaining screen time: ${e.toString()}');
    }
  }

  /// Format minutes to human-readable string
  String formatMinutes(int minutes) {
    try {
      if (minutes < 0) {
        throw Exception('Minutes cannot be negative');
      }

      if (minutes == 0) {
        return '0m';
      }

      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;

      if (hours == 0) {
        return '${remainingMinutes}m';
      }

      if (remainingMinutes == 0) {
        return '${hours}h';
      }

      return '${hours}h ${remainingMinutes}m';
    } catch (e) {
      throw Exception('Failed to format minutes: ${e.toString()}');
    }
  }

  /// Get formatted screen time status
  String getScreenTimeStatus(int usedMinutes, int dailyLimit) {
    try {
      if (usedMinutes < 0 || dailyLimit < 0) {
        throw Exception('Time values cannot be negative');
      }

      final remaining = getRemainingScreenTime(dailyLimit, usedMinutes);
      final usedFormatted = formatMinutes(usedMinutes);
      final remainingFormatted = formatMinutes(remaining);

      return 'Used: $usedFormatted / $remainingFormatted remaining';
    } catch (e) {
      throw Exception('Failed to get screen time status: ${e.toString()}');
    }
  }

  // ======================= APP RANKING =======================

  /// Get top apps by usage
  List<MapEntry<String, int>> getTopApps(
    Map<String, int> usageMap,
    int count,
  ) {
    try {
      if (count < 1) {
        throw Exception('Count must be at least 1');
      }

      if (usageMap.isEmpty) {
        return [];
      }

      final sortedEntries = usageMap.entries.toList();
      sortedEntries.sort((a, b) => b.value.compareTo(a.value));

      return sortedEntries.take(count).toList();
    } catch (e) {
      throw Exception('Failed to get top apps: ${e.toString()}');
    }
  }

  /// Get app usage percentage
  double getAppUsagePercentage(int appMinutes, int totalMinutes) {
    try {
      if (appMinutes < 0 || totalMinutes < 0) {
        throw Exception('Time values cannot be negative');
      }

      if (totalMinutes == 0) {
        return 0.0;
      }

      final percentage = (appMinutes / totalMinutes) * 100;
      return double.parse(percentage.toStringAsFixed(2));
    } catch (e) {
      throw Exception('Failed to calculate usage percentage: ${e.toString()}');
    }
  }

  // ======================= ANALYTICS =======================

  /// Get total daily usage by category
  Future<Map<String, int>> getDailyUsageByCategory(
    List<AppRule> rules,
    Map<String, int> usageMap,
  ) async {
    try {
      final categoryUsage = <String, int>{};

      for (final entry in usageMap.entries) {
        String category = 'Other';

        // Find category from rules
        for (final rule in rules) {
          if (rule.packageName == entry.key) {
            category = rule.appName;
            break;
          }
        }

        categoryUsage[category] = (categoryUsage[category] ?? 0) + entry.value;
      }

      return categoryUsage;
    } catch (e) {
      throw Exception('Failed to get daily usage by category: ${e.toString()}');
    }
  }

  /// Check if daily limit reached
  bool isDailyLimitReached(int usedMinutes, int dailyLimit) {
    try {
      if (usedMinutes < 0 || dailyLimit < 0) {
        throw Exception('Time values cannot be negative');
      }

      return usedMinutes >= dailyLimit;
    } catch (e) {
      throw Exception('Failed to check daily limit: ${e.toString()}');
    }
  }

  /// Calculate weekly average usage
  double calculateWeeklyAverage(List<int> dailyMinutes) {
    try {
      if (dailyMinutes.isEmpty) {
        return 0.0;
      }

      if (dailyMinutes.any((m) => m < 0)) {
        throw Exception('All daily minutes must be non-negative');
      }

      final total = dailyMinutes.reduce((a, b) => a + b);
      final average = total / dailyMinutes.length;

      return double.parse(average.toStringAsFixed(2));
    } catch (e) {
      throw Exception('Failed to calculate weekly average: ${e.toString()}');
    }
  }

  /// Get usage trend (increasing, stable, decreasing)
  String getUsageTrend(int previousWeekAverage, int currentWeekAverage) {
    try {
      if (previousWeekAverage < 0 || currentWeekAverage < 0) {
        throw Exception('Average values cannot be negative');
      }

      final difference = currentWeekAverage - previousWeekAverage;

      if (difference > 10) {
        return 'Increasing';
      } else if (difference < -10) {
        return 'Decreasing';
      } else {
        return 'Stable';
      }
    } catch (e) {
      throw Exception('Failed to get usage trend: ${e.toString()}');
    }
  }
}
