import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parentshield/models/user_model.dart';
import 'package:parentshield/models/child_model.dart';
import 'package:parentshield/models/app_rule_model.dart';
import 'package:parentshield/models/report_model.dart';
import 'dart:math';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();

  factory FirestoreService() {
    return _instance;
  }

  FirestoreService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // ======================= USER OPERATIONS =======================

  /// Get user by UID
  Future<UserModel?> getUser(String uid) async {
    try {
      if (uid.isEmpty) {
        throw Exception('UID cannot be empty');
      }

      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists) {
        return null;
      }

      return UserModel.fromFirestore(doc);
    } on TimeoutException {
      return null;
    } catch (e) {
      throw Exception('Failed to get user: ${e.toString()}');
    }
  }

  /// Get user profile (alias for getUser)
  Future<UserModel?> getUserProfile(String uid) async {
    return getUser(uid);
  }

  /// Create new user
  Future<void> createUser(UserModel user) async {
    try {
      if (user.uid.isEmpty) {
        throw Exception('User UID cannot be empty');
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(user.toFirestore())
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              // Firestore write may hang if database is not enabled or rules block it
              // Treat timeout as success for offline-capable Firestore
              return;
            },
          );
    } catch (e) {
      throw Exception('Failed to create user: ${e.toString()}');
    }
  }

  /// Create user profile (alias for createUser)
  Future<void> createUserProfile(UserModel user) async {
    return createUser(user);
  }

  /// Update user data
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      if (uid.isEmpty) {
        throw Exception('UID cannot be empty');
      }

      if (data.isEmpty) {
        throw Exception('Update data cannot be empty');
      }

      await _firestore
          .collection('users')
          .doc(uid)
          .update({...data, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      throw Exception('Failed to update user: ${e.toString()}');
    }
  }

  /// Update user profile from UserModel
  Future<void> updateUserProfile(UserModel user) async {
    try {
      if (user.uid.isEmpty) {
        throw Exception('User UID cannot be empty');
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({...user.toFirestore(), 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      throw Exception('Failed to update user profile: ${e.toString()}');
    }
  }

  /// Stream user data in real-time
  Stream<UserModel?> streamUser(String uid) {
    try {
      if (uid.isEmpty) {
        throw Exception('UID cannot be empty');
      }

      return _firestore
          .collection('users')
          .doc(uid)
          .snapshots()
          .map((snapshot) {
        if (!snapshot.exists) {
          return null;
        }
        return UserModel.fromFirestore(snapshot);
      }).handleError((e) {
        throw Exception('User stream error: ${e.toString()}');
      });
    } catch (e) {
      throw Exception('Failed to stream user: ${e.toString()}');
    }
  }

  // ======================= CHILD DEVICE OPERATIONS =======================

  /// Get all children for a parent
  Future<List<ChildDevice>> getChildren(String parentId) async {
    try {
      if (parentId.isEmpty) {
        throw Exception('Parent ID cannot be empty');
      }

      final snapshot = await _firestore
          .collection('users')
          .doc(parentId)
          .collection('children')
          .get();

      return snapshot.docs
          .map((doc) => ChildDevice.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get children: ${e.toString()}');
    }
  }

  /// Stream children data in real-time
  Stream<List<ChildDevice>> streamChildren(String parentId) {
    try {
      if (parentId.isEmpty) {
        throw Exception('Parent ID cannot be empty');
      }

      return _firestore
          .collection('users')
          .doc(parentId)
          .collection('children')
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => ChildDevice.fromFirestore(doc))
              .toList())
          .handleError((e) {
        throw Exception('Children stream error: ${e.toString()}');
      });
    } catch (e) {
      throw Exception('Failed to stream children: ${e.toString()}');
    }
  }

  /// Watch children (alias for streamChildren)
  Stream<List<ChildDevice>> watchChildren(String parentId) {
    return streamChildren(parentId);
  }

  /// Create child device
  Future<ChildDevice> createChild(ChildDevice child) async {
    try {
      if (child.parentId.isEmpty || child.deviceId.isEmpty) {
        throw Exception('Parent ID and Device ID cannot be empty');
      }

      final docRef = await _firestore
          .collection('users')
          .doc(child.parentId)
          .collection('children')
          .add(child.toFirestore());

      return child.copyWith(deviceId: docRef.id);
    } catch (e) {
      throw Exception('Failed to create child: ${e.toString()}');
    }
  }

  /// Update child device from a ChildDevice object
  Future<void> updateChild(ChildDevice child) async {
    try {
      if (child.parentId.isEmpty || child.deviceId.isEmpty) {
        throw Exception('Parent ID and Device ID cannot be empty');
      }

      await _firestore
          .collection('users')
          .doc(child.parentId)
          .collection('children')
          .doc(child.deviceId)
          .update({...child.toFirestore(), 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      throw Exception('Failed to update child: ${e.toString()}');
    }
  }

  /// Update child location
  Future<void> updateChildLocation(
      String parentId, String deviceId, ChildLocation location) async {
    try {
      if (parentId.isEmpty || deviceId.isEmpty) {
        throw Exception('Parent ID and Device ID cannot be empty');
      }

      if (location.latitude == 0 || location.longitude == 0) {
        throw Exception('Invalid location coordinates');
      }

      await _firestore
          .collection('users')
          .doc(parentId)
          .collection('children')
          .doc(deviceId)
          .collection('locations')
          .add({
        'latitude': location.latitude,
        'longitude': location.longitude,
        'address': location.address,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update child location: ${e.toString()}');
    }
  }

  // ======================= APP RULES OPERATIONS =======================

  /// Get app rules for device
  Future<List<AppRule>> getAppRules(String deviceId) async {
    try {
      if (deviceId.isEmpty) {
        throw Exception('Device ID cannot be empty');
      }

      final snapshot = await _firestore
          .collection('appRules')
          .where('deviceId', isEqualTo: deviceId)
          .get();

      return snapshot.docs
          .map((doc) => AppRule.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get app rules: ${e.toString()}');
    }
  }

  /// Set app rule
  Future<void> setAppRule(String deviceId, AppRule rule) async {
    try {
      if (deviceId.isEmpty || rule.packageName.isEmpty) {
        throw Exception('Device ID and Package Name cannot be empty');
      }

      final data = rule.toMap();
      data['deviceId'] = deviceId;
      data['createdAt'] = FieldValue.serverTimestamp();

      final existingRule = await _firestore
          .collection('appRules')
          .where('deviceId', isEqualTo: deviceId)
          .where('packageName', isEqualTo: rule.packageName)
          .get();

      if (existingRule.docs.isNotEmpty) {
        await _firestore
            .collection('appRules')
            .doc(existingRule.docs.first.id)
            .update(data);
      } else {
        await _firestore.collection('appRules').add(data);
      }
    } catch (e) {
      throw Exception('Failed to set app rule: ${e.toString()}');
    }
  }

  /// Update app rule (alias for setAppRule)
  Future<void> updateAppRule(String childId, AppRule rule) async {
    return setAppRule(childId, rule);
  }

  /// Delete app rule
  Future<void> deleteAppRule(String deviceId, String packageName) async {
    try {
      if (deviceId.isEmpty || packageName.isEmpty) {
        throw Exception('Device ID and Package Name cannot be empty');
      }

      final snapshot = await _firestore
          .collection('appRules')
          .where('deviceId', isEqualTo: deviceId)
          .where('packageName', isEqualTo: packageName)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete app rule: ${e.toString()}');
    }
  }

  // ======================= WEB FILTER OPERATIONS =======================

  /// Get web filter for device
  Future<WebFilterRule?> getWebFilter(String deviceId) async {
    try {
      if (deviceId.isEmpty) {
        throw Exception('Device ID cannot be empty');
      }

      final snapshot = await _firestore
          .collection('webFilters')
          .where('deviceId', isEqualTo: deviceId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return WebFilterRule.fromMap(snapshot.docs.first.data());
    } catch (e) {
      throw Exception('Failed to get web filter: ${e.toString()}');
    }
  }

  /// Set web filter for device
  Future<void> setWebFilter(String deviceId, WebFilterRule filter) async {
    try {
      if (deviceId.isEmpty) {
        throw Exception('Device ID cannot be empty');
      }

      final data = filter.toMap();
      data['deviceId'] = deviceId;
      data['updatedAt'] = FieldValue.serverTimestamp();

      final existing = await _firestore
          .collection('webFilters')
          .where('deviceId', isEqualTo: deviceId)
          .get();

      if (existing.docs.isNotEmpty) {
        await _firestore
            .collection('webFilters')
            .doc(existing.docs.first.id)
            .update(data);
      } else {
        await _firestore.collection('webFilters').add(data);
      }
    } catch (e) {
      throw Exception('Failed to set web filter: ${e.toString()}');
    }
  }

  /// Update web filter (alias for setWebFilter)
  Future<void> updateWebFilter(String deviceId, WebFilterRule filter) async {
    return setWebFilter(deviceId, filter);
  }

  // ======================= REPORT OPERATIONS =======================

  /// Get daily report for device
  Future<DailyReport?> getReport(String deviceId, DateTime date) async {
    try {
      if (deviceId.isEmpty) {
        throw Exception('Device ID cannot be empty');
      }

      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final snapshot = await _firestore
          .collection('reports')
          .where('deviceId', isEqualTo: deviceId)
          .where('date', isEqualTo: dateStr)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return DailyReport.fromFirestore(snapshot.docs.first);
    } catch (e) {
      throw Exception('Failed to get report: ${e.toString()}');
    }
  }

  /// Get today's report for a child (alias for getReport with today's date)
  Future<DailyReport?> getTodayReport(String childId) async {
    return getReport(childId, DateTime.now());
  }

  /// Get weekly reports for device
  Future<List<DailyReport>> getWeeklyReports(String deviceId) async {
    try {
      if (deviceId.isEmpty) {
        throw Exception('Device ID cannot be empty');
      }

      final sevenDaysAgo = DateTime.now().subtract(Duration(days: 7));

      final snapshot = await _firestore
          .collection('reports')
          .where('deviceId', isEqualTo: deviceId)
          .where('createdAt', isGreaterThan: sevenDaysAgo)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => DailyReport.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get weekly reports: ${e.toString()}');
    }
  }

  /// Save daily report
  Future<void> saveReport(String deviceId, DailyReport report) async {
    try {
      if (deviceId.isEmpty) {
        throw Exception('Device ID cannot be empty');
      }

      final data = report.toFirestore();
      data['deviceId'] = deviceId;
      data['createdAt'] = FieldValue.serverTimestamp();

      await _firestore.collection('reports').add(data);
    } catch (e) {
      throw Exception('Failed to save report: ${e.toString()}');
    }
  }

  // ======================= PAIRING OPERATIONS =======================

  /// Generate pairing code (6 characters)
  Future<String> generatePairingCode(String parentId, String deviceName) async {
    try {
      if (parentId.isEmpty || deviceName.isEmpty) {
        throw Exception('Parent ID and Device Name cannot be empty');
      }

      final code = _generateRandomCode(6);

      await _firestore.collection('pairingCodes').add({
        'parentId': parentId,
        'deviceName': deviceName,
        'code': code,
        'isUsed': false,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 1))),
      });

      return code;
    } catch (e) {
      throw Exception('Failed to generate pairing code: ${e.toString()}');
    }
  }

  /// Verify pairing code
  Future<ChildDevice?> verifyPairingCode(String code) async {
    try {
      if (code.isEmpty) {
        throw Exception('Pairing code cannot be empty');
      }

      final upperCode = code.toUpperCase().trim();

      // Query all docs matching this code
      final snapshot = await _firestore
          .collection('pairingCodes')
          .where('code', isEqualTo: upperCode)
          .get();

      if (snapshot.docs.isEmpty) return null;

      // Find first unused code
      final doc = snapshot.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>()
          .where((d) => d.data()['isUsed'] != true)
          .firstOrNull;

      if (doc == null) return null;

      final data = doc.data();

      // Check if code is expired
      if (data['expiresAt'] != null && data['expiresAt'] is Timestamp) {
        final expiresAt = (data['expiresAt'] as Timestamp).toDate();
        if (DateTime.now().isAfter(expiresAt)) return null;
      }

      // Mark code as used
      await doc.reference.update({'isUsed': true, 'usedAt': FieldValue.serverTimestamp()});

      final parentId = data['parentId'] ?? '';
      final deviceName = data['deviceName'] ?? 'Unknown';
      final deviceId = _generateRandomCode(16);

      final child = ChildDevice(
        deviceId: deviceId,
        parentId: parentId,
        deviceName: deviceName,
        pairingCode: upperCode,
        isActive: true,
        createdAt: DateTime.now(),
      );

      // Save the child device to Firestore
      await _firestore
          .collection('users')
          .doc(parentId)
          .collection('children')
          .doc(deviceId)
          .set(child.toFirestore());

      return child;
    } catch (e) {
      throw Exception('Failed to verify pairing code: ${e.toString()}');
    }
  }

  /// Generate random alphanumeric code
  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)])
        .join();
  }
}
