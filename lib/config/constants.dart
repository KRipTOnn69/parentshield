/// Constants and configuration values for ParentShield app
import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'ParentShield';
  static const String appVersion = '1.0.0';
  static const int pinLength = 4;
  static const int maxDailyScreenTimeMinutes = 480; // 8 hours
  static const int defaultDailyLimitMinutes = 180; // 3 hours
  static const Duration sessionTimeout = Duration(minutes: 15);
  static const int maxLoginAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 15);
}

class AppColors {
  // Primary colors
  static const Color navy = Color(0xFF0F1B2D);
  static const Color darkNavy = Color(0xFF0A1220);
  static const Color teal = Color(0xFF00B4D8);
  static const Color tealDark = Color(0xFF0077B6);

  // Secondary colors
  static const Color orange = Color(0xFFFF6B35);

  // Neutral colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF0F4F8);
  static const Color lightGray = Color(0xFFE2E8F0);
  static const Color midGray = Color(0xFF64748B);
  static const Color darkText = Color(0xFF1E293B);
  static const Color black = Color(0xFF000000);

  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
}

class AppTextStyles {
  static const TextStyle headingXL = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );

  static const TextStyle headingLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.3,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.3,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
}

class FirestorePaths {
  static const String users = 'users';
  static const String children = 'children';
  static const String rules = 'rules';
  static const String reports = 'reports';
  static const String appBlocking = 'appBlocking';
  static const String webFilter = 'webFilter';
  static const String screenTime = 'screenTime';
  static const String locationHistory = 'locationHistory';

  // Sub-collection paths
  static String userChildren(String userId) => '$users/$userId/$children';
  static String childRules(String childDeviceId) => '$children/$childDeviceId/$rules';
  static String childReports(String childDeviceId) => '$children/$childDeviceId/$reports';
  static String childScreenTime(String childDeviceId) => '$children/$childDeviceId/$screenTime';
  static String childLocationHistory(String childDeviceId) =>
      '$children/$childDeviceId/$locationHistory';
}

class WebFilterCategories {
  static const List<String> all = [
    'adult',
    'gambling',
    'violence',
    'drugs',
    'illegal',
    'malware',
    'phishing',
    'cryptocurrency',
  ];

  static const List<String> defaultBlocked = [
    'adult',
    'gambling',
    'violence',
    'drugs',
    'illegal',
    'malware',
    'phishing',
  ];
}
