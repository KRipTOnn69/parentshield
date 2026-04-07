import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:parentshield/config/constants.dart';
import 'package:parentshield/providers/auth_provider.dart';
import 'package:parentshield/providers/child_provider.dart';
import 'package:parentshield/services/app_blocker_service.dart';

// ─── Data model for an app entry ───
class _AppData {
  final String name;
  final IconData icon;
  bool isBlocked;
  int dailyLimitMinutes;
  int usedMinutesToday;

  _AppData({
    required this.name,
    required this.icon,
    this.isBlocked = false,
    this.dailyLimitMinutes = 120,
    this.usedMinutesToday = 0,
  });
}

// ─── Data model for a safe zone ───
class _SafeZone {
  String name;
  String address;
  int radiusMeters;

  _SafeZone({
    required this.name,
    required this.address,
    this.radiusMeters = 500,
  });
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  String _searchQuery = '';
  bool _deviceLocked = false;
  String _selectedChild = 'Alex\'s Phone';
  final List<String> _childDevices = ['Alex\'s Phone', 'Sam\'s Tablet'];

  // ─── Live app data (persisted to Firestore) ───
  late List<_AppData> _apps;

  // ─── Live safe zone data ───
  late List<_SafeZone> _safeZones;

  // ─── Screen time tracking ───
  int _dailyLimitMinutes = 240; // 4 hours
  int _usedTodayMinutes = 154; // 2h 34m

  // ─── Weekly usage (minutes per day) ───
  final List<int> _weeklyMinutes = [95, 110, 80, 130, 140, 154, 170];

  // ─── Blocked attempts ───
  int _blockedAttempts = 7;

  @override
  void initState() {
    super.initState();
    _apps = [
      _AppData(name: 'YouTube', icon: Icons.play_circle_fill, dailyLimitMinutes: 120, usedMinutesToday: 45),
      _AppData(name: 'TikTok', icon: Icons.music_note, dailyLimitMinutes: 60, usedMinutesToday: 30),
      _AppData(name: 'Instagram', icon: Icons.camera_alt, dailyLimitMinutes: 90, usedMinutesToday: 20),
      _AppData(name: 'WhatsApp', icon: Icons.message, dailyLimitMinutes: 0, usedMinutesToday: 15),
      _AppData(name: 'Chrome', icon: Icons.public, dailyLimitMinutes: 180, usedMinutesToday: 25),
      _AppData(name: 'Roblox', icon: Icons.sports_esports, dailyLimitMinutes: 30, usedMinutesToday: 0),
      _AppData(name: 'Snapchat', icon: Icons.photo_camera_front, dailyLimitMinutes: 45, usedMinutesToday: 10),
      _AppData(name: 'Netflix', icon: Icons.movie, dailyLimitMinutes: 60, usedMinutesToday: 9),
    ];
    _safeZones = [
      _SafeZone(name: 'Home', address: '123 Main Street', radiusMeters: 500),
      _SafeZone(name: 'School', address: '456 Education Ave', radiusMeters: 200),
      _SafeZone(name: 'Park', address: '789 Green Lane', radiusMeters: 300),
    ];
    _loadFromFirestore();
    _syncBlockedAppsToNative();
  }

  /// Get current user UID from AuthProvider or Firebase Auth directly
  String? _getCurrentUid() {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid != null && uid.isNotEmpty) return uid;
    // Fallback to Firebase Auth directly
    final firebaseUser = fb_auth.FirebaseAuth.instance.currentUser;
    debugPrint('[ParentShield] AuthProvider uid=$uid, Firebase Auth uid=${firebaseUser?.uid}');
    return firebaseUser?.uid;
  }

  // ─── Firestore sync ───
  Future<void> _loadFromFirestore() async {
    try {
      final uid = _getCurrentUid();
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('dashboard')
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        if (data['dailyLimitMinutes'] != null) {
          setState(() => _dailyLimitMinutes = data['dailyLimitMinutes'] as int);
        }
        if (data['blockedApps'] != null) {
          final blocked = List<String>.from(data['blockedApps'] as List);
          for (var app in _apps) {
            app.isBlocked = blocked.contains(app.name);
          }
          setState(() {});
        }
        if (data['safeZones'] != null) {
          final zones = List<Map<String, dynamic>>.from(data['safeZones'] as List);
          setState(() {
            _safeZones = zones
                .map((z) => _SafeZone(
                      name: z['name'] as String,
                      address: z['address'] as String,
                      radiusMeters: z['radiusMeters'] as int,
                    ))
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Firestore load: $e');
    }
  }

  Future<void> _saveToFirestore() async {
    try {
      final uid = _getCurrentUid();
      if (uid == null) {
        debugPrint('[ParentShield] Cannot save to Firestore: user not authenticated');
        return;
      }
      debugPrint('[ParentShield] Saving blocked apps to Firestore for uid: $uid');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('dashboard')
          .set({
        'dailyLimitMinutes': _dailyLimitMinutes,
        'blockedApps': _apps.where((a) => a.isBlocked).map((a) => a.name).toList(),
        'safeZones': _safeZones
            .map((z) => {
                  'name': z.name,
                  'address': z.address,
                  'radiusMeters': z.radiusMeters,
                })
            .toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore save: $e');
    }

    // Sync blocked apps to native blocker service
    _syncBlockedAppsToNative();
  }

  Future<void> _syncBlockedAppsToNative() async {
    final blockerService = AppBlockerService();
    // Map app display names to known package names
    final packageMap = {
      'YouTube': 'com.google.android.youtube',
      'TikTok': 'com.zhiliaoapp.musically',
      'Instagram': 'com.instagram.android',
      'WhatsApp': 'com.whatsapp',
      'Chrome': 'com.android.chrome',
      'Roblox': 'com.roblox.client',
      'Snapchat': 'com.snapchat.android',
      'Netflix': 'com.netflix.mediaclient',
    };

    final blockedPackages = <String>[];
    for (final app in _apps) {
      if (app.isBlocked && packageMap.containsKey(app.name)) {
        blockedPackages.add(packageMap[app.name]!);
      }
    }

    await blockerService.updateBlockedApps(blockedPackages);
    await blockerService.setBlockerEnabled(blockedPackages.isNotEmpty);
  }

  Future<void> _handleLogout() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  int get _blockedCount => _apps.where((a) => a.isBlocked).length;

  String _formatMinutes(int m) {
    if (m <= 0) return 'Unlimited';
    final h = m ~/ 60;
    final min = m % 60;
    if (h > 0 && min > 0) return '${h}h ${min}m';
    if (h > 0) return '${h}h';
    return '${min}m';
  }

  // ══════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        elevation: 0,
        title: Text('ParentShield',
            style: AppTextStyles.headingMedium
                .copyWith(color: AppColors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              icon: const Icon(Icons.notifications_none),
              color: AppColors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No new notifications')),
                );
              }),
          IconButton(
              icon: const Icon(Icons.logout),
              color: AppColors.white,
              onPressed: _handleLogout),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(),
          _buildAppsTab(),
          _buildLocationTab(),
          _buildReportsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.teal,
        unselectedItemColor: AppColors.midGray,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.apps_outlined), activeIcon: Icon(Icons.apps), label: 'Apps'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on_outlined), activeIcon: Icon(Icons.location_on), label: 'Location'),
          BottomNavigationBarItem(icon: Icon(Icons.assessment_outlined), activeIcon: Icon(Icons.assessment), label: 'Reports'),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  TAB 1 — HOME
  // ══════════════════════════════════════════════════════════════════
  Widget _buildHomeTab() {
    final userName = context.read<AuthProvider>().user?.name ?? 'Parent';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 8),
        Text('Hello, $userName!',
            style: AppTextStyles.headingMedium
                .copyWith(color: AppColors.darkText, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text("Here's what's happening today",
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.midGray)),
        const SizedBox(height: 20),

        // ─── Child selector ───
        GestureDetector(
          onTap: () => _showChildSelector(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.teal.withOpacity(0.3)),
            ),
            child: Row(children: [
              CircleAvatar(
                  backgroundColor: AppColors.teal.withOpacity(0.1),
                  child: Icon(Icons.phone_android, color: AppColors.teal)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Active Device',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.midGray)),
                  Text(_selectedChild,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.darkText, fontWeight: FontWeight.w600)),
                ]),
              ),
              Icon(Icons.expand_more, color: AppColors.teal),
            ]),
          ),
        ),
        const SizedBox(height: 20),

        // ─── Stat cards ───
        _StatCard(
          title: 'Screen Time',
          value: _formatMinutes(_usedTodayMinutes),
          subtitle: '/ ${_formatMinutes(_dailyLimitMinutes)} limit',
          icon: Icons.schedule,
          color: AppColors.teal,
          onTap: () => setState(() => _selectedIndex = 3),
        ),
        const SizedBox(height: 12),
        _StatCard(
          title: 'Apps Blocked',
          value: '$_blockedCount',
          subtitle: 'active blocks',
          icon: Icons.block,
          color: AppColors.orange,
          onTap: () => setState(() => _selectedIndex = 1),
        ),
        const SizedBox(height: 12),
        _StatCard(
          title: 'Location',
          value: _safeZones.isNotEmpty ? _safeZones.first.name : 'Unknown',
          subtitle: 'last updated 2m ago',
          icon: Icons.location_on,
          color: AppColors.teal,
          onTap: () => setState(() => _selectedIndex = 2),
        ),
        const SizedBox(height: 12),
        _StatCard(
          title: 'Blocked Attempts',
          value: '$_blockedAttempts',
          subtitle: 'this week',
          icon: Icons.notifications_active,
          color: AppColors.orange,
          onTap: () => setState(() => _selectedIndex = 3),
        ),
        const SizedBox(height: 24),

        // ─── Quick Actions ───
        Text('Quick Actions',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.darkText, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _QuickActionButton(
                  label: _deviceLocked ? 'Unlock Device' : 'Lock Device',
                  icon: _deviceLocked ? Icons.lock_open : Icons.lock,
                  onTap: () {
                    setState(() => _deviceLocked = !_deviceLocked);
                    _saveToFirestore();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(_deviceLocked ? 'Device locked remotely' : 'Device unlocked'),
                      backgroundColor: _deviceLocked ? AppColors.orange : AppColors.success,
                    ));
                  })),
          const SizedBox(width: 12),
          Expanded(
              child: _QuickActionButton(
                  label: 'View Location',
                  icon: Icons.location_on,
                  onTap: () => setState(() => _selectedIndex = 2))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _QuickActionButton(
                  label: 'Manage Apps',
                  icon: Icons.apps,
                  onTap: () => setState(() => _selectedIndex = 1))),
          const SizedBox(width: 12),
          Expanded(
              child: _QuickActionButton(
                  label: 'Set Time Limit',
                  icon: Icons.timer,
                  onTap: () => _showTimeLimitDialog())),
        ]),
      ]),
    );
  }

  void _showChildSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Select Device',
              style: AppTextStyles.headingSmall.copyWith(color: AppColors.darkText)),
          const SizedBox(height: 16),
          ..._childDevices.map((d) => ListTile(
                leading: Icon(Icons.phone_android,
                    color: d == _selectedChild ? AppColors.teal : AppColors.midGray),
                title: Text(d),
                trailing: d == _selectedChild
                    ? Icon(Icons.check_circle, color: AppColors.teal)
                    : null,
                onTap: () {
                  setState(() => _selectedChild = d);
                  Navigator.pop(ctx);
                },
              )),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showGeneratePairingCode();
            },
            icon: const Icon(Icons.add),
            label: const Text('Pair New Device'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushNamed('/child-management');
            },
            icon: Icon(Icons.manage_accounts, color: AppColors.teal),
            label: Text('Manage Children',
                style: TextStyle(color: AppColors.teal)),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            },
            icon: Icon(Icons.child_care, color: AppColors.orange),
            label: Text('Switch to Child Mode',
                style: TextStyle(color: AppColors.orange)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.orange.withOpacity(0.5)),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _showGeneratePairingCode() async {
    // Generate a random 6-character pairing code
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final code = List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();

    // Get current user UID - try multiple sources
    final authProvider = context.read<AuthProvider>();
    var uid = authProvider.user?.uid;

    // Fallback: get directly from Firebase Auth
    if (uid == null || uid.isEmpty) {
      final firebaseUser = fb_auth.FirebaseAuth.instance.currentUser;
      uid = firebaseUser?.uid;
      debugPrint('[ParentShield] AuthProvider user was null, Firebase Auth user: ${firebaseUser?.email}, uid: $uid');
    }

    if (uid == null || uid.isEmpty) {
      debugPrint('[ParentShield] Cannot generate pairing code: user not authenticated');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in again to generate a pairing code'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    debugPrint('[ParentShield] Generating pairing code: $code for uid: $uid');

    // Save to Firestore and WAIT for it to complete
    try {
      await FirebaseFirestore.instance.collection('pairingCodes').add({
        'parentId': uid,
        'deviceName': _selectedChild,
        'code': code,
        'isUsed': false,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 1))),
      });
      debugPrint('[ParentShield] Pairing code saved to Firestore: $code');
    } catch (e) {
      debugPrint('[ParentShield] Failed to save pairing code: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate code: $e'), backgroundColor: AppColors.orange),
        );
      }
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.devices, color: AppColors.teal),
          const SizedBox(width: 8),
          const Text('Pairing Code'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'Enter this code on the child\'s device:',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.midGray),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: code.split('').map((c) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(c,
                    style: AppTextStyles.headingXL.copyWith(
                      color: AppColors.teal,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    )),
              )).toList(),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copied to clipboard')),
              );
            },
            icon: Icon(Icons.copy, size: 16, color: AppColors.teal),
            label: Text('Copy Code',
                style: TextStyle(color: AppColors.teal)),
          ),
          const SizedBox(height: 8),
          Text(
            'Code expires in 1 hour',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.midGray),
          ),
        ]),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showTimeLimitDialog() {
    int tempLimit = _dailyLimitMinutes;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          title: const Text('Set Daily Screen Time Limit'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_formatMinutes(tempLimit),
                style: AppTextStyles.headingLarge.copyWith(color: AppColors.teal)),
            const SizedBox(height: 16),
            Slider(
              value: tempLimit.toDouble(),
              min: 30,
              max: 480,
              divisions: 18,
              activeColor: AppColors.teal,
              label: _formatMinutes(tempLimit),
              onChanged: (v) => setDialogState(() => tempLimit = v.round()),
            ),
            Text('Slide to adjust (30 min – 8 hours)',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.midGray)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
              onPressed: () {
                setState(() => _dailyLimitMinutes = tempLimit);
                _saveToFirestore();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Daily limit set to ${_formatMinutes(tempLimit)}')));
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  TAB 2 — APPS
  // ══════════════════════════════════════════════════════════════════
  Widget _buildAppsTab() {
    final filtered = _searchQuery.isEmpty
        ? _apps
        : _apps.where((a) => a.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Container(
      color: AppColors.offWhite,
      child: Column(children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.midGray.withOpacity(0.2)),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search apps...',
                hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.midGray),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: AppColors.midGray),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),
        // Summary bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${filtered.length} apps',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.midGray)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$_blockedCount blocked',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.orange, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        // App list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final app = filtered[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: app.isBlocked
                          ? AppColors.orange.withOpacity(0.3)
                          : AppColors.midGray.withOpacity(0.1)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (app.isBlocked ? AppColors.orange : AppColors.teal).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(app.icon,
                        color: app.isBlocked ? AppColors.orange : AppColors.teal, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(app.name,
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.darkText, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                          app.isBlocked
                              ? 'Blocked'
                              : 'Used ${_formatMinutes(app.usedMinutesToday)} / ${_formatMinutes(app.dailyLimitMinutes)}',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: app.isBlocked ? AppColors.orange : AppColors.midGray)),
                      // Usage progress bar
                      if (!app.isBlocked && app.dailyLimitMinutes > 0) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (app.usedMinutesToday / app.dailyLimitMinutes).clamp(0.0, 1.0),
                            minHeight: 4,
                            backgroundColor: AppColors.midGray.withOpacity(0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                app.usedMinutesToday > app.dailyLimitMinutes * 0.8
                                    ? AppColors.orange
                                    : AppColors.teal),
                          ),
                        ),
                      ],
                    ]),
                  ),
                  Column(children: [
                    Switch(
                      value: !app.isBlocked,
                      onChanged: (allowed) {
                        setState(() => app.isBlocked = !allowed);
                        if (!allowed) setState(() => _blockedAttempts++);
                        _saveToFirestore();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(allowed ? '${app.name} allowed' : '${app.name} blocked'),
                          backgroundColor: allowed ? AppColors.success : AppColors.orange,
                          duration: const Duration(seconds: 1),
                        ));
                      },
                      activeColor: AppColors.teal,
                    ),
                    // Edit time limit
                    GestureDetector(
                      onTap: () => _showAppTimeLimitDialog(app),
                      child: Text('Edit limit',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.teal, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }

  void _showAppTimeLimitDialog(_AppData app) {
    int tempLimit = app.dailyLimitMinutes;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          title: Text('${app.name} Daily Limit'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(tempLimit == 0 ? 'Unlimited' : _formatMinutes(tempLimit),
                style: AppTextStyles.headingLarge.copyWith(color: AppColors.teal)),
            const SizedBox(height: 16),
            Slider(
              value: tempLimit.toDouble(),
              min: 0,
              max: 300,
              divisions: 12,
              activeColor: AppColors.teal,
              onChanged: (v) => setDialogState(() => tempLimit = v.round()),
            ),
            Text('0 = Unlimited',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.midGray)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
              onPressed: () {
                setState(() => app.dailyLimitMinutes = tempLimit);
                _saveToFirestore();
                Navigator.pop(ctx);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  TAB 3 — LOCATION
  // ══════════════════════════════════════════════════════════════════
  Widget _buildLocationTab() {
    return Container(
      color: AppColors.offWhite,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Map placeholder with child marker
          Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [AppColors.teal.withOpacity(0.15), AppColors.navy.withOpacity(0.08)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: AppColors.teal.withOpacity(0.3)),
            ),
            child: Stack(children: [
              // Grid lines
              ...List.generate(5, (i) => Positioned(
                    top: (i + 1) * 36.0,
                    left: 0,
                    right: 0,
                    child: Container(height: 0.5, color: AppColors.midGray.withOpacity(0.15)),
                  )),
              ...List.generate(7, (i) => Positioned(
                    left: (i + 1) * 48.0,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 0.5, color: AppColors.midGray.withOpacity(0.15)),
                  )),
              // Child location marker
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Text(_selectedChild,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.darkText, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 4),
                  Icon(Icons.location_on, size: 40, color: AppColors.teal),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.teal.withOpacity(0.1),
                      border: Border.all(color: AppColors.teal.withOpacity(0.3), width: 1),
                    ),
                  ),
                ]),
              ),
              // Refresh button
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Location refreshed'))),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.refresh, color: AppColors.teal, size: 20),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Current location card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, color: AppColors.success, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('In Safe Zone',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
                  Text(_safeZones.isNotEmpty ? '${_safeZones.first.name} — ${_safeZones.first.address}' : 'Unknown',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.midGray)),
                  const SizedBox(height: 4),
                  Text('Updated just now',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.midGray)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // Safe Zones header
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Safe Zones (${_safeZones.length})',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.darkText, fontWeight: FontWeight.w600)),
            ElevatedButton.icon(
              onPressed: _showAddSafeZoneDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Zone'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // Safe zones list
          ..._safeZones.asMap().entries.map((entry) {
            final i = entry.key;
            final z = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.midGray.withOpacity(0.1)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.location_on, color: AppColors.teal, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(z.name,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.darkText, fontWeight: FontWeight.w600)),
                    Text('${z.address} • ${z.radiusMeters}m radius',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.midGray)),
                  ]),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: AppColors.orange, size: 20),
                  onPressed: () {
                    setState(() => _safeZones.removeAt(i));
                    _saveToFirestore();
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${z.name} removed')));
                  },
                ),
              ]),
            );
          }),
        ]),
      ),
    );
  }

  void _showAddSafeZoneDialog() {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    int radius = 500;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          title: const Text('Add Safe Zone'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Zone Name', hintText: 'e.g. Home, School'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addrCtrl,
                decoration: const InputDecoration(labelText: 'Address', hintText: '123 Main Street'),
              ),
              const SizedBox(height: 16),
              Text('Radius: ${radius}m',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.teal)),
              Slider(
                value: radius.toDouble(),
                min: 100,
                max: 1000,
                divisions: 9,
                activeColor: AppColors.teal,
                label: '${radius}m',
                onChanged: (v) => setDialogState(() => radius = v.round()),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  setState(() => _safeZones.add(_SafeZone(
                      name: nameCtrl.text,
                      address: addrCtrl.text.isNotEmpty ? addrCtrl.text : 'No address',
                      radiusMeters: radius)));
                  _saveToFirestore();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('${nameCtrl.text} added')));
                }
              },
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  TAB 4 — REPORTS
  // ══════════════════════════════════════════════════════════════════
  Widget _buildReportsTab() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxMin = _weeklyMinutes.reduce((a, b) => a > b ? a : b);
    final totalWeek = _weeklyMinutes.reduce((a, b) => a + b);

    // Sort apps by usage for report
    final sortedApps = List<_AppData>.from(_apps)
      ..sort((a, b) => b.usedMinutesToday.compareTo(a.usedMinutesToday));

    return Container(
      color: AppColors.offWhite,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ─── Today's Screen Time ───
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.teal.withOpacity(0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text("Today's Screen Time",
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.darkText, fontWeight: FontWeight.w600)),
                GestureDetector(
                  onTap: () => _showTimeLimitDialog(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Edit Limit',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.teal, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_formatMinutes(_usedTodayMinutes),
                    style: AppTextStyles.headingLarge.copyWith(color: AppColors.teal)),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('/ ${_formatMinutes(_dailyLimitMinutes)} limit',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.midGray)),
                ),
              ]),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _dailyLimitMinutes > 0
                      ? (_usedTodayMinutes / _dailyLimitMinutes).clamp(0.0, 1.0)
                      : 0,
                  minHeight: 12,
                  backgroundColor: AppColors.midGray.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      _usedTodayMinutes > _dailyLimitMinutes * 0.8
                          ? AppColors.orange
                          : AppColors.teal),
                ),
              ),
              if (_usedTodayMinutes > _dailyLimitMinutes * 0.8) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.warning_amber, size: 16, color: AppColors.orange),
                  const SizedBox(width: 4),
                  Text('Approaching daily limit',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.orange)),
                ]),
              ],
            ]),
          ),
          const SizedBox(height: 20),

          // ─── Weekly Chart ───
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.midGray.withOpacity(0.1)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('This Week',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.darkText, fontWeight: FontWeight.w600)),
                Text('Total: ${_formatMinutes(totalWeek)}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.teal, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                height: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    final h = maxMin > 0 ? (_weeklyMinutes[i] / maxMin) * 90 : 0.0;
                    final isToday = i == DateTime.now().weekday - 1;
                    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text('${_weeklyMinutes[i]}m',
                          style: TextStyle(fontSize: 9, color: AppColors.midGray)),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: 28,
                        height: h,
                        decoration: BoxDecoration(
                          color: isToday ? AppColors.orange : AppColors.teal,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(days[i],
                          style: AppTextStyles.bodySmall.copyWith(
                              color: isToday ? AppColors.orange : AppColors.darkText,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
                    ]);
                  }),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // ─── Most Used Apps ───
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.midGray.withOpacity(0.1)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Most Used Apps',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.darkText, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ...sortedApps.take(5).map((app) {
                final pct = _usedTodayMinutes > 0
                    ? (app.usedMinutesToday / _usedTodayMinutes)
                    : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Icon(app.icon, color: AppColors.teal, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(app.name,
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.darkText)),
                          Text(_formatMinutes(app.usedMinutesToday),
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.teal, fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: pct.clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor: AppColors.midGray.withOpacity(0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.teal),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                );
              }),
            ]),
          ),
          const SizedBox(height: 20),

          // ─── Blocked Attempts ───
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.orange.withOpacity(0.2)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.block, color: AppColors.orange, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Blocked Attempts',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.midGray)),
                  const SizedBox(height: 4),
                  Text('$_blockedAttempts this week',
                      style: AppTextStyles.headingSmall
                          .copyWith(color: AppColors.darkText, fontWeight: FontWeight.bold)),
                ]),
              ),
              Icon(Icons.trending_up, color: AppColors.orange, size: 28),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════ SHARED WIDGETS ═══════════════════════

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppTextStyles.bodySmall.copyWith(color: AppColors.midGray)),
              const SizedBox(height: 4),
              Row(children: [
                Text(value,
                    style: AppTextStyles.headingSmall
                        .copyWith(color: AppColors.darkText, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.midGray)),
              ]),
            ]),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.midGray),
        ]),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.teal.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.teal.withOpacity(0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: AppColors.teal, size: 24),
          const SizedBox(height: 6),
          Text(label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.teal, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
