import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parentshield/config/constants.dart';
import 'package:parentshield/providers/child_provider.dart';
import 'package:parentshield/services/app_blocker_service.dart';
import 'package:parentshield/widgets/pin_verification_dialog.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({Key? key}) : super(key: key);

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> with WidgetsBindingObserver {
  late int _remainingMinutes;
  late int _totalMinutes;
  final AppBlockerService _blockerService = AppBlockerService();
  bool _isAccessibilityEnabled = false;
  bool _isBlockerActive = false;
  int _blockedAppsCount = 0;
  Timer? _refreshTimer;
  String _syncStatus = 'Waiting...';
  List<String> _blockedAppNames = [];
  bool _isDeviceAdminActive = false;

  @override
  void initState() {
    super.initState();
    _remainingMinutes = 65;
    _totalMinutes = 120;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChildProvider>().loadStatus();
      _initBlocker();
    });

    // Periodically refresh blocker status
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshBlockerStatus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshBlockerStatus();
    }
  }

  Future<void> _initBlocker() async {
    final isEnabled = await _blockerService.isAccessibilityServiceEnabled();
    final isActive = await _blockerService.isBlockerEnabled();
    final blockedApps = await _blockerService.getBlockedApps();
    final isAdmin = await _blockerService.isDeviceAdminActive();

    if (mounted) {
      setState(() {
        _isAccessibilityEnabled = isEnabled;
        _isBlockerActive = isActive;
        _blockedAppsCount = blockedApps.length;
        _isDeviceAdminActive = isAdmin;
      });
    }

    // Auto-enable blocker on child device if accessibility is enabled
    if (isEnabled && !isActive) {
      await _blockerService.setBlockerEnabled(true);
      if (mounted) {
        setState(() => _isBlockerActive = true);
      }
    }

    // Activate child mode on native side (blocks Settings access)
    await _blockerService.setChildModeActive(true);

    // Sync blocked apps from parent's Firestore settings
    await _syncBlockedAppsFromParent();
  }

  /// Fetch blocked apps from parent's Firestore and push to native blocker
  Future<void> _syncBlockedAppsFromParent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final parentId = prefs.getString('paired_parent_id');

      if (parentId == null || parentId.isEmpty) {
        debugPrint('[ParentShield] Child not paired - no parentId found');
        if (mounted) setState(() => _syncStatus = 'Not paired');
        return;
      }

      debugPrint('[ParentShield] Syncing blocked apps from parent: $parentId');
      if (mounted) setState(() => _syncStatus = 'Syncing...');

      // Read parent's dashboard settings to get blocked app names
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(parentId)
          .collection('settings')
          .doc('dashboard')
          .get();

      if (!doc.exists || doc.data() == null) {
        debugPrint('[ParentShield] No dashboard settings found for parent: $parentId');
        if (mounted) setState(() => _syncStatus = 'No parent settings found');
        return;
      }

      final data = doc.data()!;
      final blockedNames = List<String>.from(data['blockedApps'] as List? ?? []);
      debugPrint('[ParentShield] Blocked app names from parent: $blockedNames');

      // Map display names to package names
      const packageMap = {
        'YouTube': 'com.google.android.youtube',
        'TikTok': 'com.zhiliaoapp.musically',
        'Instagram': 'com.instagram.android',
        'WhatsApp': 'com.whatsapp',
        'Chrome': 'com.android.chrome',
        'Roblox': 'com.roblox.client',
        'Snapchat': 'com.snapchat.android',
        'Netflix': 'com.netflix.mediaclient',
        'Facebook': 'com.facebook.katana',
        'Twitter': 'com.twitter.android',
        'Telegram': 'org.telegram.messenger',
        'Reddit': 'com.reddit.frontpage',
        'Spotify': 'com.spotify.music',
        'Pinterest': 'com.pinterest',
        'Twitch': 'tv.twitch.android.app',
        'Minecraft': 'com.mojang.minecraftpe',
      };

      final blockedPackages = <String>[];
      for (final name in blockedNames) {
        if (packageMap.containsKey(name)) {
          blockedPackages.add(packageMap[name]!);
        }
      }

      debugPrint('[ParentShield] Pushing ${blockedPackages.length} blocked packages to native: $blockedPackages');

      // ALWAYS push to native — even if empty (to clear old blocks)
      final updateResult = await _blockerService.updateBlockedApps(blockedPackages);
      debugPrint('[ParentShield] updateBlockedApps result: $updateResult');

      if (blockedPackages.isNotEmpty) {
        final enableResult = await _blockerService.setBlockerEnabled(true);
        debugPrint('[ParentShield] setBlockerEnabled result: $enableResult');
      }

      // Verify what native side actually has
      final nativeBlocked = await _blockerService.getBlockedApps();
      final nativeEnabled = await _blockerService.isBlockerEnabled();
      debugPrint('[ParentShield] Native verification - blocked: $nativeBlocked, enabled: $nativeEnabled');

      if (mounted) {
        setState(() {
          _blockedAppsCount = nativeBlocked.length;
          _blockedAppNames = blockedNames;
          _isBlockerActive = nativeEnabled;
          _syncStatus = blockedNames.isEmpty
              ? 'No apps blocked by parent'
              : '${blockedNames.length} apps blocked: ${blockedNames.join(", ")}';
        });
      }
    } catch (e) {
      debugPrint('[ParentShield] Failed to sync blocked apps: $e');
      if (mounted) setState(() => _syncStatus = 'Sync failed: $e');
    }
  }

  Future<void> _refreshBlockerStatus() async {
    final isEnabled = await _blockerService.isAccessibilityServiceEnabled();
    final isActive = await _blockerService.isBlockerEnabled();
    final blockedApps = await _blockerService.getBlockedApps();
    final isAdmin = await _blockerService.isDeviceAdminActive();

    if (mounted) {
      setState(() {
        _isAccessibilityEnabled = isEnabled;
        _isBlockerActive = isActive;
        _blockedAppsCount = blockedApps.length;
        _isDeviceAdminActive = isAdmin;
      });
    }

    // Re-sync from Firestore every refresh
    await _syncBlockedAppsFromParent();
  }

  Future<void> _showLogoutDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final parentId = prefs.getString('paired_parent_id');

    if (parentId == null || parentId.isEmpty) {
      // No parent ID — allow exit without PIN
      await _performExit();
      return;
    }

    if (!mounted) return;

    final verified = await showPinVerificationDialog(context, parentId);
    if (verified && mounted) {
      await _performExit();
    }
  }

  Future<void> _performExit() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('paired_parent_id');
    await prefs.remove('paired_device_id');
    await prefs.remove('paired_device_name');
    await prefs.setBool('is_paired', false);
    await _blockerService.setBlockerEnabled(false);
    await _blockerService.setChildModeActive(false);
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hours = _remainingMinutes ~/ 60;
    final minutes = _remainingMinutes % 60;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.teal,
                AppColors.teal.withOpacity(0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 32.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ParentShield',
                            style: AppTextStyles.headingMedium.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You\'re protected',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: AppColors.white,
                        ),
                        onSelected: (value) {
                          if (value == 'logout') {
                            _showLogoutDialog();
                          } else if (value == 'refresh') {
                            _syncBlockedAppsFromParent();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'refresh',
                            child: Row(
                              children: [
                                Icon(Icons.refresh, size: 20),
                                SizedBox(width: 8),
                                Text('Refresh Rules'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'logout',
                            child: Row(
                              children: [
                                Icon(Icons.logout, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Exit Child Mode', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Setup Required Banner
                  if (!_isAccessibilityEnabled || !_isDeviceAdminActive) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.6),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.yellow, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'SETUP REQUIRED',
                            style: AppTextStyles.headingMedium.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Step 1: Accessibility Service
                          _SetupStep(
                            stepNumber: '1',
                            title: 'Accessibility Service',
                            description: 'Required for app blocking',
                            isComplete: _isAccessibilityEnabled,
                            buttonText: 'Enable',
                            onPressed: () async {
                              await _blockerService.openAccessibilitySettings();
                            },
                          ),
                          const SizedBox(height: 12),

                          // Step 2: Device Admin
                          _SetupStep(
                            stepNumber: '2',
                            title: 'Device Protection',
                            description: 'Prevents app uninstall',
                            isComplete: _isDeviceAdminActive,
                            buttonText: 'Activate',
                            onPressed: () async {
                              await _blockerService.requestDeviceAdmin();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 48),
                  // Circular Progress Indicator
                  Center(
                    child: SizedBox(
                      width: 240,
                      height: 240,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 240,
                            height: 240,
                            child: CircularProgressIndicator(
                              value: _remainingMinutes / _totalMinutes,
                              strokeWidth: 12,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.white,
                              ),
                              backgroundColor:
                                  AppColors.white.withOpacity(0.2),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$hours',
                                style: AppTextStyles.headingXL.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 56,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'h',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.white.withOpacity(0.8),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${minutes.toString().padLeft(2, '0')}',
                                    style: AppTextStyles.headingMedium.copyWith(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'm',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.white.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Time Remaining Text
                  Text(
                    'Screen time remaining',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.white.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  // Active Rules
                  Text(
                    'Active Rules',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _RuleCard(
                    icon: Icons.shield,
                    title: 'App Blocking',
                    subtitle: _isAccessibilityEnabled && _isBlockerActive
                        ? '$_blockedAppsCount apps blocked'
                        : !_isAccessibilityEnabled
                            ? 'Accessibility OFF'
                            : 'Blocker OFF',
                    description: _isAccessibilityEnabled && _isBlockerActive
                        ? (_blockedAppNames.isNotEmpty
                            ? _blockedAppNames.join(', ')
                            : 'No apps blocked by parent')
                        : 'Enable accessibility service to activate',
                    isActive: _isAccessibilityEnabled && _isBlockerActive && _blockedAppsCount > 0,
                  ),
                  const SizedBox(height: 12),
                  _RuleCard(
                    icon: Icons.language,
                    title: 'Web Filter',
                    subtitle: 'Adult content blocked',
                    description: 'Safe browsing enabled',
                  ),
                  const SizedBox(height: 12),
                  _RuleCard(
                    icon: Icons.schedule,
                    title: 'Screen Time Limit',
                    subtitle: '2 hours per day',
                    description: '${hours}h ${minutes.toString().padLeft(2, '0')}m remaining today',
                  ),
                  const SizedBox(height: 12),
                  _RuleCard(
                    icon: Icons.location_on,
                    title: 'Location Tracking',
                    subtitle: 'Enabled',
                    description: 'Your location is shared safely',
                  ),
                  const SizedBox(height: 24),
                  // Sync Status Debug Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.white.withOpacity(0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.sync, color: AppColors.white.withOpacity(0.7), size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Sync Status',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.white.withOpacity(0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _syncStatus,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.white.withOpacity(0.6),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Accessibility: ${_isAccessibilityEnabled ? "ON" : "OFF"} | Blocker: ${_isBlockerActive ? "ON" : "OFF"} | Apps: $_blockedAppsCount',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.white.withOpacity(0.5),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Protected Badge
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.verified,
                          color: AppColors.teal,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Protected by ParentShield',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.darkText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your parent is helping keep you safe online',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.midGray,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Need Help Button
                  OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Request sent to your parent!'),
                          backgroundColor: AppColors.teal,
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: AppColors.white.withOpacity(0.5),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.help_outline,
                          color: AppColors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Request Access',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final bool isActive;

  const _RuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.white.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.white.withOpacity(0.2)
                            : AppColors.orange.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isActive
                              ? AppColors.white
                              : AppColors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.white.withOpacity(0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  final String stepNumber;
  final String title;
  final String description;
  final bool isComplete;
  final String buttonText;
  final VoidCallback onPressed;

  const _SetupStep({
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.isComplete,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isComplete
            ? Colors.green.withOpacity(0.2)
            : AppColors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isComplete
              ? Colors.green.withOpacity(0.5)
              : AppColors.white.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isComplete ? Colors.green : Colors.yellow,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isComplete
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Text(
                      stepNumber,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  isComplete ? 'Enabled' : description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          if (!isComplete)
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}
