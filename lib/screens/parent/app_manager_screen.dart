import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parentshield/config/constants.dart';
import 'package:parentshield/providers/child_provider.dart';
import 'package:parentshield/services/app_blocker_service.dart';

class AppManagerScreen extends StatefulWidget {
  const AppManagerScreen({Key? key}) : super(key: key);

  @override
  State<AppManagerScreen> createState() => _AppManagerScreenState();
}

class _AppManagerScreenState extends State<AppManagerScreen> {
  late TextEditingController _searchController;
  String _searchQuery = '';
  final AppBlockerService _blockerService = AppBlockerService();
  List<InstalledAppInfo> _installedApps = [];
  Set<String> _blockedPackages = {};
  bool _isLoading = true;
  bool _isAccessibilityEnabled = false;
  bool _isBlockerActive = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final apps = await _blockerService.getInstalledApps();
    final blockedApps = await _blockerService.getBlockedApps();
    final accessibilityEnabled = await _blockerService.isAccessibilityServiceEnabled();
    final blockerActive = await _blockerService.isBlockerEnabled();

    if (mounted) {
      setState(() {
        _installedApps = apps;
        _blockedPackages = blockedApps.toSet();
        _isAccessibilityEnabled = accessibilityEnabled;
        _isBlockerActive = blockerActive;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleAppBlock(String packageName, bool block) async {
    setState(() {
      if (block) {
        _blockedPackages.add(packageName);
      } else {
        _blockedPackages.remove(packageName);
      }
    });

    await _blockerService.updateBlockedApps(_blockedPackages.toList());
  }

  Future<void> _toggleBlockerActive(bool active) async {
    await _blockerService.setBlockerEnabled(active);
    setState(() => _isBlockerActive = active);
  }

  Future<void> _blockAll() async {
    final filtered = _getFilteredApps();
    setState(() {
      for (final app in filtered) {
        _blockedPackages.add(app.packageName);
      }
    });
    await _blockerService.updateBlockedApps(_blockedPackages.toList());
  }

  Future<void> _allowAll() async {
    final filtered = _getFilteredApps();
    setState(() {
      for (final app in filtered) {
        _blockedPackages.remove(app.packageName);
      }
    });
    await _blockerService.updateBlockedApps(_blockedPackages.toList());
  }

  List<InstalledAppInfo> _getFilteredApps() {
    if (_searchQuery.isEmpty) return _installedApps;
    final query = _searchQuery.toLowerCase();
    return _installedApps.where((app) {
      return app.appName.toLowerCase().contains(query) ||
          app.packageName.toLowerCase().contains(query) ||
          app.category.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredApps = _getFilteredApps();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: AppColors.white,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'App Manager',
          style: AppTextStyles.headingMedium.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: AppColors.white,
            onPressed: _loadData,
          ),
        ],
      ),
      body: Container(
        color: AppColors.offWhite,
        child: Column(
          children: [
            // Accessibility Service Status Banner
            if (!_isAccessibilityEnabled)
              _AccessibilityBanner(
                onEnable: () async {
                  await _blockerService.openAccessibilitySettings();
                  // Re-check after user returns
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) _loadData();
                  });
                },
              ),

            // Blocker Active Toggle
            if (_isAccessibilityEnabled)
              Container(
                color: _isBlockerActive
                    ? AppColors.teal.withOpacity(0.1)
                    : AppColors.orange.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      _isBlockerActive ? Icons.shield : Icons.shield_outlined,
                      color: _isBlockerActive ? AppColors.teal : AppColors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isBlockerActive
                                ? 'App Blocking Active'
                                : 'App Blocking Paused',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.darkText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${_blockedPackages.length} apps blocked',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.midGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isBlockerActive,
                      onChanged: _toggleBlockerActive,
                      activeColor: AppColors.teal,
                      activeTrackColor: AppColors.teal.withOpacity(0.3),
                    ),
                  ],
                ),
              ),

            // Search Bar
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search apps...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.midGray,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.teal,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          color: AppColors.midGray,
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.midGray.withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.midGray.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.teal,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: AppColors.offWhite,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            // Control Buttons
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _ControlButton(
                      label: 'Block All',
                      icon: Icons.block,
                      color: AppColors.orange,
                      onTap: _blockAll,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ControlButton(
                      label: 'Allow All',
                      icon: Icons.check_circle,
                      color: AppColors.teal,
                      onTap: _allowAll,
                    ),
                  ),
                ],
              ),
            ),
            // Apps List
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.teal,
                      ),
                    )
                  : filteredApps.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.apps,
                                size: 64,
                                color: AppColors.midGray.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No apps match "$_searchQuery"'
                                    : 'No apps found',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.midGray,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: AppColors.teal,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredApps.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final app = filteredApps[index];
                              final isBlocked =
                                  _blockedPackages.contains(app.packageName);

                              return _AppTile(
                                appName: app.appName,
                                packageName: app.packageName,
                                category: app.category,
                                isBlocked: isBlocked,
                                isSystemApp: app.isSystemApp,
                                onBlockToggle: (blocked) {
                                  _toggleAppBlock(app.packageName, blocked);
                                },
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessibilityBanner extends StatelessWidget {
  final VoidCallback onEnable;

  const _AccessibilityBanner({required this.onEnable});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.warning.withOpacity(0.15),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Accessibility Service Required',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.darkText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enable ParentShield in Accessibility Settings to block apps.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.midGray,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onEnable,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  final String appName;
  final String packageName;
  final String category;
  final bool isBlocked;
  final bool isSystemApp;
  final Function(bool) onBlockToggle;

  const _AppTile({
    required this.appName,
    required this.packageName,
    required this.category,
    required this.isBlocked,
    required this.isSystemApp,
    required this.onBlockToggle,
  });

  IconData _getCategoryIcon() {
    switch (category) {
      case 'Games':
        return Icons.sports_esports;
      case 'Social Media':
        return Icons.people;
      case 'Video':
        return Icons.play_circle;
      case 'Audio':
        return Icons.music_note;
      case 'Photo':
        return Icons.photo;
      case 'News':
        return Icons.newspaper;
      case 'Maps':
        return Icons.map;
      case 'Productivity':
        return Icons.work;
      default:
        return Icons.apps;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBlocked
              ? AppColors.orange.withOpacity(0.3)
              : AppColors.teal.withOpacity(0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isBlocked
                  ? AppColors.orange.withOpacity(0.1)
                  : AppColors.teal.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getCategoryIcon(),
              color: isBlocked ? AppColors.orange : AppColors.teal,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        appName,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.darkText,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSystemApp) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.midGray.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'System',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.midGray,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  category,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.midGray,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                isBlocked ? 'Blocked' : 'Allowed',
                style: AppTextStyles.bodySmall.copyWith(
                  color: isBlocked ? AppColors.orange : AppColors.teal,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
              Switch(
                value: !isBlocked,
                onChanged: (allowed) => onBlockToggle(!allowed),
                activeColor: AppColors.teal,
                activeTrackColor: AppColors.teal.withOpacity(0.3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ControlButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
