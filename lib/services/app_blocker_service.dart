import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class InstalledAppInfo {
  final String packageName;
  final String appName;
  final String category;
  final bool isSystemApp;

  InstalledAppInfo({
    required this.packageName,
    required this.appName,
    required this.category,
    required this.isSystemApp,
  });

  factory InstalledAppInfo.fromMap(Map<dynamic, dynamic> map) {
    return InstalledAppInfo(
      packageName: map['packageName'] as String? ?? '',
      appName: map['appName'] as String? ?? '',
      category: map['category'] as String? ?? 'Other',
      isSystemApp: map['isSystemApp'] as bool? ?? false,
    );
  }
}

class AppBlockerService {
  static final AppBlockerService _instance = AppBlockerService._internal();
  factory AppBlockerService() => _instance;
  AppBlockerService._internal();

  static const _channel = MethodChannel('com.parentshield/app_blocker');

  /// Get list of installed apps from native Android
  Future<List<InstalledAppInfo>> getInstalledApps() async {
    try {
      if (kIsWeb) return [];
      final List<dynamic> result = await _channel.invokeMethod('getInstalledApps');
      return result
          .map((app) => InstalledAppInfo.fromMap(app as Map<dynamic, dynamic>))
          .toList();
    } on PlatformException catch (e) {
      debugPrint('Failed to get installed apps: ${e.message}');
      return [];
    }
  }

  /// Check if the Accessibility Service is enabled
  Future<bool> isAccessibilityServiceEnabled() async {
    try {
      if (kIsWeb) return false;
      final result = await _channel.invokeMethod<bool>('isAccessibilityServiceEnabled');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Failed to check accessibility service: ${e.message}');
      return false;
    }
  }

  /// Open Android Accessibility Settings to enable the service
  Future<void> openAccessibilitySettings() async {
    try {
      if (kIsWeb) return;
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      debugPrint('Failed to open accessibility settings: ${e.message}');
    }
  }

  /// Update the list of blocked app packages
  Future<bool> updateBlockedApps(List<String> packages) async {
    try {
      if (kIsWeb) return false;
      await _channel.invokeMethod('updateBlockedApps', {'packages': packages});
      return true;
    } on PlatformException catch (e) {
      debugPrint('Failed to update blocked apps: ${e.message}');
      return false;
    }
  }

  /// Enable or disable the app blocker
  Future<bool> setBlockerEnabled(bool enabled) async {
    try {
      if (kIsWeb) return false;
      await _channel.invokeMethod('setBlockerEnabled', {'enabled': enabled});
      return true;
    } on PlatformException catch (e) {
      debugPrint('Failed to set blocker enabled: ${e.message}');
      return false;
    }
  }

  /// Check if the blocker is currently enabled
  Future<bool> isBlockerEnabled() async {
    try {
      if (kIsWeb) return false;
      final result = await _channel.invokeMethod<bool>('isBlockerEnabled');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Failed to check blocker enabled: ${e.message}');
      return false;
    }
  }

  /// Get currently blocked packages
  Future<List<String>> getBlockedApps() async {
    try {
      if (kIsWeb) return [];
      final List<dynamic> result = await _channel.invokeMethod('getBlockedApps');
      return result.cast<String>();
    } on PlatformException catch (e) {
      debugPrint('Failed to get blocked apps: ${e.message}');
      return [];
    }
  }

  /// Set child mode active/inactive (blocks Settings access when active)
  Future<bool> setChildModeActive(bool active) async {
    try {
      if (kIsWeb) return false;
      await _channel.invokeMethod('setChildModeActive', {'active': active});
      return true;
    } on PlatformException catch (e) {
      debugPrint('Failed to set child mode: ${e.message}');
      return false;
    }
  }

  /// Request Device Admin activation (prevents app uninstall)
  Future<bool> requestDeviceAdmin() async {
    try {
      if (kIsWeb) return false;
      final result = await _channel.invokeMethod<bool>('requestDeviceAdmin');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Failed to request device admin: ${e.message}');
      return false;
    }
  }

  /// Check if Device Admin is active
  Future<bool> isDeviceAdminActive() async {
    try {
      if (kIsWeb) return false;
      final result = await _channel.invokeMethod<bool>('isDeviceAdminActive');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Failed to check device admin: ${e.message}');
      return false;
    }
  }
}
