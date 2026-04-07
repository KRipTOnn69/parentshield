import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentshield/models/child_model.dart';
import 'package:parentshield/models/app_rule_model.dart';
import 'package:parentshield/models/report_model.dart';
import 'package:parentshield/services/firestore_service.dart';

class ChildProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;

  List<ChildDevice> _children = [];
  ChildDevice? _selectedChild;
  List<AppRule> _appRules = [];
  WebFilterRule? _webFilter;
  DailyReport? _todayReport;
  List<DailyReport> _weeklyReports = [];
  bool _isLoading = false;
  String? _error;

  StreamSubscription? _childrenSubscription;

  ChildProvider() : _firestoreService = FirestoreService();

  // Getters
  List<ChildDevice> get children => _children;
  ChildDevice? get selectedChild => _selectedChild;
  List<AppRule> get appRules => _appRules;
  WebFilterRule? get webFilter => _webFilter;
  DailyReport? get todayReport => _todayReport;
  List<DailyReport> get weeklyReports => _weeklyReports;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get errorMessage => _error;

  Future<void> loadChildren([String? parentId]) async {
    if (parentId == null) {
      _children = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _childrenSubscription?.cancel();
      _childrenSubscription = _firestoreService
          .streamChildren(parentId)
          .listen(
            (children) {
              _children = children;
              if (_selectedChild != null &&
                  !_children.any(
                      (c) => c.deviceId == _selectedChild!.deviceId)) {
                _selectedChild =
                    _children.isNotEmpty ? _children[0] : null;
              }
              _isLoading = false;
              _error = null;
              notifyListeners();
            },
            onError: (e) {
              _error = 'Failed to load children';
              _isLoading = false;
              notifyListeners();
            },
          );
    } catch (e) {
      _error = 'Failed to load children';
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectChild(ChildDevice child) {
    _selectedChild = child;
    _error = null;
    notifyListeners();

    loadAppRules();
    loadWebFilter();
    loadTodayReport();
  }

  Future<void> loadStatus() async {
    // No-op placeholder
  }

  Future<void> loadApps() async {
    await loadAppRules();
  }

  Future<void> loadLocation() async {
    // No-op placeholder — location is loaded via selectedChild.lastLocation
  }

  Future<void> loadReports() async {
    await loadWeeklyReports();
  }

  Future<String?> generatePairingCode() async {
    if (_selectedChild == null) {
      _error = 'No child selected';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final code = await _firestoreService.generatePairingCode(
        _selectedChild!.parentId,
        _selectedChild!.deviceName,
      );
      _isLoading = false;
      _error = null;
      notifyListeners();
      return code;
    } catch (e) {
      _error = 'Failed to generate pairing code';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> verifyPairingCode(String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _firestoreService.verifyPairingCode(code);
      _isLoading = false;

      if (result != null) {
        // Save pairing info locally so the child device remembers its parent
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('paired_parent_id', result.parentId);
        await prefs.setString('paired_device_id', result.deviceId);
        await prefs.setString('paired_device_name', result.deviceName);
        await prefs.setBool('is_paired', true);

        _selectedChild = result;
        _error = null;
        notifyListeners();
        return true;
      } else {
        _error = 'Invalid or expired pairing code';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('[ParentShield] verifyPairingCode catch: $e');
      _error = 'Pairing failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadAppRules() async {
    if (_selectedChild == null) {
      _error = 'No child selected';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _appRules =
          await _firestoreService.getAppRules(_selectedChild!.deviceId);
      _isLoading = false;
      _error = null;
    } catch (e) {
      _error = 'Failed to load app rules';
      _isLoading = false;
    }

    notifyListeners();
  }

  Future<void> updateAppRule(AppRule rule) async {
    if (_selectedChild == null) {
      _error = 'No child selected';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestoreService.setAppRule(_selectedChild!.deviceId, rule);
      final index =
          _appRules.indexWhere((r) => r.packageName == rule.packageName);
      if (index >= 0) {
        _appRules[index] = rule;
      }
      _isLoading = false;
      _error = null;
    } catch (e) {
      _error = 'Failed to update app rule';
      _isLoading = false;
    }

    notifyListeners();
  }

  Future<void> toggleAppBlock(String packageName, bool isBlocked) async {
    if (_selectedChild == null) {
      _error = 'No child selected';
      notifyListeners();
      return;
    }

    try {
      final rule =
          _appRules.firstWhere((r) => r.packageName == packageName);
      final updatedRule = rule.copyWith(isBlocked: isBlocked);
      await updateAppRule(updatedRule);
    } catch (e) {
      _error = 'Failed to update app block status';
      notifyListeners();
    }
  }

  Future<void> setAppTimeLimit(String packageName, int minutes) async {
    if (_selectedChild == null) {
      _error = 'No child selected';
      notifyListeners();
      return;
    }

    try {
      final rule =
          _appRules.firstWhere((r) => r.packageName == packageName);
      final updatedRule = rule.copyWith(dailyLimitMinutes: minutes);
      await updateAppRule(updatedRule);
    } catch (e) {
      _error = 'Failed to set app time limit';
      notifyListeners();
    }
  }

  Future<void> loadWebFilter() async {
    if (_selectedChild == null) {
      _error = 'No child selected';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _webFilter =
          await _firestoreService.getWebFilter(_selectedChild!.deviceId);
      _isLoading = false;
      _error = null;
    } catch (e) {
      _error = 'Failed to load web filter';
      _isLoading = false;
    }

    notifyListeners();
  }

  Future<void> updateWebFilter(WebFilterRule filter) async {
    if (_selectedChild == null) {
      _error = 'No child selected';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestoreService.setWebFilter(
          _selectedChild!.deviceId, filter);
      _webFilter = filter;
      _isLoading = false;
      _error = null;
    } catch (e) {
      _error = 'Failed to update web filter';
      _isLoading = false;
    }

    notifyListeners();
  }

  Future<void> loadTodayReport() async {
    if (_selectedChild == null) {
      _error = 'No child selected';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _todayReport = await _firestoreService.getReport(
          _selectedChild!.deviceId, DateTime.now());
      _isLoading = false;
      _error = null;
    } catch (e) {
      _error = 'Failed to load today report';
      _isLoading = false;
    }

    notifyListeners();
  }

  Future<void> loadWeeklyReports() async {
    if (_selectedChild == null) {
      _error = 'No child selected';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _weeklyReports = await _firestoreService
          .getWeeklyReports(_selectedChild!.deviceId);
      _isLoading = false;
      _error = null;
    } catch (e) {
      _error = 'Failed to load weekly reports';
      _isLoading = false;
    }

    notifyListeners();
  }

  Future<void> setDailyScreenTimeLimit(int minutes) async {
    if (_selectedChild == null) {
      _error = 'No child selected';
      notifyListeners();
      return;
    }

    if (minutes < 0 || minutes > 1440) {
      _error = 'Daily limit must be between 0 and 1440 minutes';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedRules = _selectedChild!.screenTimeRules.copyWith(
        dailyLimitMinutes: minutes,
      );
      await _firestoreService.updateChild(
        _selectedChild!.copyWith(screenTimeRules: updatedRules),
      );
      _selectedChild = _selectedChild!.copyWith(
        screenTimeRules: updatedRules,
      );

      final index = _children
          .indexWhere((c) => c.deviceId == _selectedChild!.deviceId);
      if (index >= 0) {
        _children[index] = _selectedChild!;
      }

      _isLoading = false;
      _error = null;
    } catch (e) {
      _error = 'Failed to set daily screen time limit';
      _isLoading = false;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _childrenSubscription?.cancel();
    super.dispose();
  }
}
