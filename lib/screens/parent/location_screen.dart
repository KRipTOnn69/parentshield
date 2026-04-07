import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:parentshield/config/constants.dart';
import 'package:parentshield/providers/auth_provider.dart';
import 'package:parentshield/providers/child_provider.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({Key? key}) : super(key: key);

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  List<SafeZone> _safeZones = [
    SafeZone(
      id: '1',
      name: 'Home',
      address: '123 Main St, Anytown USA',
      radius: 500,
      isActive: true,
      arrivedTime: '10:30 AM',
    ),
    SafeZone(
      id: '2',
      name: 'School',
      address: 'Central High School',
      radius: 300,
      isActive: false,
      arrivedTime: null,
    ),
    SafeZone(
      id: '3',
      name: 'Soccer Field',
      address: 'Community Sports Complex',
      radius: 400,
      isActive: false,
      arrivedTime: null,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChildProvider>().loadLocation();
      _loadSafeZones();
    });
  }

  String? _getCurrentUid() {
    try {
      return context.read<AuthProvider>().user?.uid ??
          fb_auth.FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return fb_auth.FirebaseAuth.instance.currentUser?.uid;
    }
  }

  Future<void> _loadSafeZones() async {
    try {
      final uid = _getCurrentUid();
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('settings').doc('safeZones')
          .get();
      if (doc.exists && doc.data() != null) {
        final zones = List<Map<String, dynamic>>.from(doc.data()!['zones'] ?? []);
        if (zones.isNotEmpty) {
          setState(() {
            _safeZones = zones.map((z) => SafeZone(
              id: z['id'] ?? '',
              name: z['name'] ?? '',
              address: z['address'] ?? '',
              radius: z['radius'] ?? 500,
              isActive: z['isActive'] ?? false,
              arrivedTime: z['arrivedTime'],
            )).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to load safe zones: $e');
    }
  }

  Future<void> _saveSafeZones() async {
    try {
      final uid = _getCurrentUid();
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('settings').doc('safeZones')
          .set({
        'zones': _safeZones.map((z) => {
          'id': z.id, 'name': z.name, 'address': z.address,
          'radius': z.radius, 'isActive': z.isActive, 'arrivedTime': z.arrivedTime,
        }).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to save safe zones: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Location',
          style: AppTextStyles.headingMedium.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: AppColors.white,
            onPressed: () => _loadSafeZones(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddSafeZoneDialog();
        },
        backgroundColor: AppColors.teal,
        child: const Icon(Icons.add),
      ),
      body: Container(
        color: AppColors.offWhite,
        child: Column(
          children: [
            // Map Container
            Container(
              height: 280,
              color: AppColors.white,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.teal.withOpacity(0.2),
                ),
              ),
              child: Stack(
                children: [
                  // Placeholder for Google Maps
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.offWhite,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map,
                            size: 64,
                            color: AppColors.teal.withOpacity(0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Google Maps Integration',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.midGray,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Child location will display here',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.midGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Location Marker
                  Positioned(
                    bottom: 120,
                    right: 80,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.teal,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.teal.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: AppColors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  // Last Updated Info
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.darkText.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.update,
                            size: 14,
                            color: AppColors.teal,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Updated 2 min ago',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.darkText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Safe Zones Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Safe Zones',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.darkText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${_safeZones.length} zones',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.midGray,
                    ),
                  ),
                ],
              ),
            ),
            // Safe Zones List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _safeZones.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _SafeZoneCard(
                    zone: _safeZones[index],
                    onEdit: () {},
                    onDelete: () {
                      setState(() => _safeZones.removeAt(index));
                      _saveSafeZones();
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showAddSafeZoneDialog() {
    final nameController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {

            return AlertDialog(
              title: Text(
                'Add Safe Zone',
                style: AppTextStyles.headingMedium.copyWith(
                  color: AppColors.darkText,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Zone Name',
                        hintText: 'e.g., Home',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: addressController,
                      decoration: InputDecoration(
                        labelText: 'Address',
                        hintText: 'Street address',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.midGray,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty) {
                      this.setState(() {
                        _safeZones.add(
                          SafeZone(
                            id: DateTime.now().toString(),
                            name: nameController.text,
                            address: addressController.text,
                            radius: 500,
                            isActive: false,
                            arrivedTime: null,
                          ),
                        );
                      });
                      _saveSafeZones();
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                  ),
                  child: Text(
                    'Add',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class SafeZone {
  final String id;
  final String name;
  final String address;
  final int radius;
  final bool isActive;
  final String? arrivedTime;

  SafeZone({
    required this.id,
    required this.name,
    required this.address,
    required this.radius,
    required this.isActive,
    required this.arrivedTime,
  });
}

class _SafeZoneCard extends StatelessWidget {
  final SafeZone zone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SafeZoneCard({
    required this.zone,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: zone.isActive
              ? AppColors.teal.withOpacity(0.3)
              : AppColors.midGray.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: zone.isActive
                      ? AppColors.teal.withOpacity(0.1)
                      : AppColors.midGray.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on,
                  color:
                      zone.isActive ? AppColors.teal : AppColors.midGray,
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
                          zone.name,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.darkText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (zone.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.teal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Active',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.teal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      zone.address,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.midGray,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (zone.isActive)
            Column(
              children: [
                const SizedBox(height: 12),
                Divider(
                  color: AppColors.midGray.withOpacity(0.2),
                  height: 1,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: AppColors.teal,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Child arrived at ${zone.arrivedTime}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.teal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Radius: ${zone.radius}m',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.midGray,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: onEdit,
                    icon: Icon(
                      Icons.edit,
                      size: 18,
                      color: AppColors.teal,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete,
                      size: 18,
                      color: AppColors.orange,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
