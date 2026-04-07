import 'package:flutter/material.dart';
import 'package:parentshield/screens/mode_selection_screen.dart';
import 'package:parentshield/screens/parent/login_screen.dart';
import 'package:parentshield/screens/parent/register_screen.dart';
import 'package:parentshield/screens/parent/pin_screen.dart';
import 'package:parentshield/screens/parent/dashboard_screen.dart';
import 'package:parentshield/screens/parent/app_manager_screen.dart';
import 'package:parentshield/screens/parent/web_filter_screen.dart';
import 'package:parentshield/screens/parent/location_screen.dart';
import 'package:parentshield/screens/parent/reports_screen.dart';
import 'package:parentshield/screens/child/pairing_screen.dart';
import 'package:parentshield/screens/child/status_screen.dart';
import 'package:parentshield/screens/child/blocked_overlay_screen.dart';
import 'package:parentshield/screens/parent/child_management_screen.dart';

/// Named route definitions for ParentShield app navigation
class AppRoutes {
  // Route names
  static const String modeSelection = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String pinSetup = '/pin-setup';
  static const String pinVerify = '/pin-verify';
  static const String pin = '/pin';
  static const String dashboard = '/dashboard';
  static const String appManager = '/app-manager';
  static const String webFilter = '/web-filter';
  static const String location = '/location';
  static const String reports = '/reports';
  static const String childPairing = '/child/pairing';
  static const String childStatus = '/child/status';
  static const String childManagement = '/child-management';
  static const String blockedOverlay = '/blocked-overlay';

  /// Generate routes for the app
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case modeSelection:
        return _buildRoute(
          settings,
          const ModeSelectionScreen(),
        );
      case login:
        return _buildRoute(
          settings,
          const LoginScreen(),
        );
      case register:
        return _buildRoute(
          settings,
          const RegisterScreen(),
        );
      case pinSetup:
        return _buildRoute(
          settings,
          const PINScreen(isSetup: true),
        );
      case pinVerify:
      case pin:
        return _buildRoute(
          settings,
          const PINScreen(isSetup: false),
        );
      case dashboard:
        return _buildRoute(
          settings,
          const DashboardScreen(),
        );
      case appManager:
        return _buildRoute(
          settings,
          const AppManagerScreen(),
        );
      case webFilter:
        return _buildRoute(
          settings,
          const WebFilterScreen(),
        );
      case location:
        return _buildRoute(
          settings,
          const LocationScreen(),
        );
      case reports:
        return _buildRoute(
          settings,
          const ReportsScreen(),
        );
      case childManagement:
        return _buildRoute(
          settings,
          const ChildManagementScreen(),
        );
      case childPairing:
        return _buildRoute(
          settings,
          const PairingScreen(),
        );
      case childStatus:
        return _buildRoute(
          settings,
          const StatusScreen(),
        );
      case blockedOverlay:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          settings,
          BlockedOverlayScreen(
            appName: args?['appName'] as String?,
            reason: args?['reason'] as String?,
          ),
        );
      default:
        return _buildRoute(
          settings,
          const ModeSelectionScreen(),
        );
    }
  }

  /// Helper method to build route with fade transition
  static PageRoute<dynamic> _buildRoute(
    RouteSettings settings,
    Widget page,
  ) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => page,
    );
  }
}
