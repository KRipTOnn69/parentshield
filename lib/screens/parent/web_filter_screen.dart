import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:parentshield/config/constants.dart';
import 'package:parentshield/providers/auth_provider.dart';
import 'package:parentshield/providers/child_provider.dart';

class WebFilterScreen extends StatefulWidget {
  const WebFilterScreen({Key? key}) : super(key: key);

  @override
  State<WebFilterScreen> createState() => _WebFilterScreenState();
}

class _WebFilterScreenState extends State<WebFilterScreen> {
  late TextEditingController _urlController;
  late TextEditingController _allowlistController;
  bool _masterEnabled = true;
  bool _isSaving = false;
  Map<String, bool> _categoryFilters = {
    'Adult Content': true,
    'Gambling': true,
    'Violence': true,
    'Social Media': false,
    'Streaming': false,
    'Shopping': false,
  };
  List<String> _customBlocklist = [
    'example-bad.com',
    'restricted-site.org',
  ];
  List<String> _customAllowlist = [
    'educational-resource.edu',
    'homework-help.org',
  ];

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _allowlistController = TextEditingController();
    _loadWebFilterFromFirestore();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _allowlistController.dispose();
    super.dispose();
  }

  Future<void> _loadWebFilterFromFirestore() async {
    try {
      final uid = _getCurrentUid();
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('settings').doc('webFilter')
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _masterEnabled = data['masterEnabled'] as bool? ?? true;
          if (data['categoryFilters'] != null) {
            final cats = Map<String, dynamic>.from(data['categoryFilters']);
            cats.forEach((k, v) {
              if (_categoryFilters.containsKey(k)) _categoryFilters[k] = v as bool;
            });
          }
          if (data['blocklist'] != null) _customBlocklist = List<String>.from(data['blocklist']);
          if (data['allowlist'] != null) _customAllowlist = List<String>.from(data['allowlist']);
        });
      }
    } catch (e) {
      debugPrint('Failed to load web filter: $e');
    }
  }

  String? _getCurrentUid() {
    try {
      return context.read<AuthProvider>().user?.uid ??
          fb_auth.FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return fb_auth.FirebaseAuth.instance.currentUser?.uid;
    }
  }

  Future<void> _saveWebFilter() async {
    setState(() => _isSaving = true);
    try {
      final uid = _getCurrentUid();
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('settings').doc('webFilter')
          .set({
        'masterEnabled': _masterEnabled,
        'categoryFilters': _categoryFilters,
        'blocklist': _customBlocklist,
        'allowlist': _customAllowlist,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Web filter settings saved'), backgroundColor: AppColors.teal),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: AppColors.orange),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
          'Web Filter',
          style: AppTextStyles.headingMedium.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        color: AppColors.offWhite,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              // Master Toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _masterEnabled
                        ? AppColors.teal.withOpacity(0.2)
                        : AppColors.orange.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Web Filtering',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.darkText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _masterEnabled
                              ? 'Filtering is enabled'
                              : 'Filtering is disabled',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.midGray,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _masterEnabled,
                      onChanged: (value) {
                        setState(() => _masterEnabled = value);
                      },
                      activeColor: AppColors.teal,
                      activeTrackColor: AppColors.teal.withOpacity(0.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Category Filters Section
              Text(
                'Content Categories',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.darkText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ..._categoryFilters.entries.map((entry) {
                return _CategoryToggle(
                  title: entry.key,
                  value: entry.value,
                  onChanged: (value) {
                    setState(() => _categoryFilters[entry.key] = value);
                  },
                );
              }).toList(),
              const SizedBox(height: 24),
              // Custom Blocklist Section
              Text(
                'Custom Blocklist',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.darkText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.midGray.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Add sites to block',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.midGray,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            decoration: InputDecoration(
                              hintText: 'example.com',
                              hintStyle: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.midGray,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: AppColors.midGray.withOpacity(0.3),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: AppColors.midGray.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.teal,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: AppColors.offWhite,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (_urlController.text.isNotEmpty) {
                              setState(() {
                                _customBlocklist.add(_urlController.text);
                                _urlController.clear();
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          child: Icon(
                            Icons.add,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_customBlocklist.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Divider(
                            color: AppColors.midGray.withOpacity(0.2),
                          ),
                          const SizedBox(height: 8),
                          ..._customBlocklist.asMap().entries.map((e) {
                            return _CustomUrlTile(
                              url: e.value,
                              onDelete: () {
                                setState(() => _customBlocklist.removeAt(e.key));
                              },
                            );
                          }).toList(),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Custom Allowlist Section
              Text(
                'Custom Allowlist',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.darkText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.midGray.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Add sites to allow',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.midGray,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _allowlistController,
                            decoration: InputDecoration(
                              hintText: 'example.com',
                              hintStyle: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.midGray,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: AppColors.midGray.withOpacity(0.3),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: AppColors.midGray.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.teal,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: AppColors.offWhite,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final text = _allowlistController.text.trim();
                            if (text.isNotEmpty) {
                              setState(() {
                                _customAllowlist.add(text);
                                _allowlistController.clear();
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          child: Icon(
                            Icons.add,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_customAllowlist.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Divider(
                            color: AppColors.midGray.withOpacity(0.2),
                          ),
                          const SizedBox(height: 8),
                          ..._customAllowlist.asMap().entries.map((e) {
                            return _CustomUrlTile(
                              url: e.value,
                              isAllowlist: true,
                              onDelete: () {
                                setState(() => _customAllowlist.removeAt(e.key));
                              },
                            );
                          }).toList(),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveWebFilter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  disabledBackgroundColor: AppColors.teal.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.white)))
                    : Text(
                        'Save Changes',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryToggle extends StatelessWidget {
  final String title;
  final bool value;
  final Function(bool) onChanged;

  const _CategoryToggle({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.midGray.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.darkText,
              fontWeight: FontWeight.w500,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.teal,
            activeTrackColor: AppColors.teal.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}

class _CustomUrlTile extends StatelessWidget {
  final String url;
  final bool isAllowlist;
  final VoidCallback onDelete;

  const _CustomUrlTile({
    required this.url,
    this.isAllowlist = false,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isAllowlist
            ? AppColors.teal.withOpacity(0.05)
            : AppColors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAllowlist
              ? AppColors.teal.withOpacity(0.2)
              : AppColors.orange.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isAllowlist ? Icons.check_circle : Icons.block,
                size: 16,
                color: isAllowlist ? AppColors.teal : AppColors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                url,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.darkText,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: onDelete,
            child: Icon(
              Icons.close,
              size: 16,
              color: AppColors.midGray,
            ),
          ),
        ],
      ),
    );
  }
}
