import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:provider/provider.dart';
import 'package:parentshield/config/constants.dart';
import 'package:parentshield/providers/auth_provider.dart';
import 'package:parentshield/services/firestore_service.dart';

class ChildManagementScreen extends StatefulWidget {
  const ChildManagementScreen({Key? key}) : super(key: key);

  @override
  State<ChildManagementScreen> createState() => _ChildManagementScreenState();
}

class _ChildManagementScreenState extends State<ChildManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  String? _getCurrentUid() {
    try {
      return context.read<AuthProvider>().user?.uid ??
          fb_auth.FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return fb_auth.FirebaseAuth.instance.currentUser?.uid;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _getCurrentUid();

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
          'Manage Children',
          style: AppTextStyles.headingMedium.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddChildDialog(),
        backgroundColor: AppColors.teal,
        icon: const Icon(Icons.add),
        label: const Text('Add Child'),
      ),
      body: Container(
        color: AppColors.offWhite,
        child: uid == null
            ? const Center(child: Text('Not authenticated'))
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('children')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.devices, size: 64, color: AppColors.midGray.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text(
                            'No children paired yet',
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.midGray),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap "Add Child" to generate a pairing code',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.midGray),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final deviceId = docs[index].id;
                      final deviceName = data['deviceName'] ?? 'Unknown Device';
                      final isActive = data['isActive'] ?? false;
                      final createdAt = data['createdAt'];

                      String createdStr = '';
                      if (createdAt is Timestamp) {
                        final d = createdAt.toDate();
                        createdStr = '${d.day}/${d.month}/${d.year}';
                      }

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive
                                ? AppColors.teal.withOpacity(0.3)
                                : AppColors.midGray.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.teal.withOpacity(0.1)
                                    : AppColors.midGray.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.phone_android,
                                color: isActive ? AppColors.teal : AppColors.midGray,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    deviceName,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.darkText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: isActive ? Colors.green : AppColors.midGray,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isActive ? 'Active' : 'Inactive',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: isActive ? Colors.green : AppColors.midGray,
                                        ),
                                      ),
                                      if (createdStr.isNotEmpty) ...[
                                        Text(
                                          '  |  Paired $createdStr',
                                          style: AppTextStyles.bodySmall.copyWith(
                                            color: AppColors.midGray,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'rename') {
                                  _showRenameDialog(uid!, deviceId, deviceName);
                                } else if (value == 'unpair') {
                                  _showUnpairDialog(uid!, deviceId, deviceName);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'rename',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 18),
                                      SizedBox(width: 8),
                                      Text('Rename'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'unpair',
                                  child: Row(
                                    children: [
                                      Icon(Icons.link_off, size: 18, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Unpair', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  void _showAddChildDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Child Device', style: AppTextStyles.headingMedium.copyWith(color: AppColors.darkText)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter a name for the child\'s device, then share the pairing code with them.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.midGray),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Device Name',
                hintText: 'e.g., Alex\'s Phone',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.midGray)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              await _generateAndShowCode(name);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
            child: Text('Generate Code', style: TextStyle(color: AppColors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndShowCode(String deviceName) async {
    final uid = _getCurrentUid();
    if (uid == null) return;

    try {
      final code = await _firestoreService.generatePairingCode(uid, deviceName);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              const Text('Pairing Code'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Share this code with your child. It expires in 1 hour.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.midGray),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.teal.withOpacity(0.3)),
                ),
                child: Text(
                  code,
                  style: AppTextStyles.headingXL.copyWith(
                    color: AppColors.teal,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Device: $deviceName',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.midGray),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code copied to clipboard')),
                );
              },
              child: const Text('Copy Code'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
              child: Text('Done', style: TextStyle(color: AppColors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate code: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showRenameDialog(String uid, String deviceId, String currentName) {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Device'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Device Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.midGray)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('children')
                  .doc(deviceId)
                  .update({'deviceName': newName});
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
            child: Text('Save', style: TextStyle(color: AppColors.white)),
          ),
        ],
      ),
    );
  }

  void _showUnpairDialog(String uid, String deviceId, String deviceName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unpair Device'),
        content: Text('Remove "$deviceName" from your paired devices? The child will need to pair again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.midGray)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('children')
                  .doc(deviceId)
                  .delete();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$deviceName unpaired')),
                );
              }
            },
            child: const Text('Unpair', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
