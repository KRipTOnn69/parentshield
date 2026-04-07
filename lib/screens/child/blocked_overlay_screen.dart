import 'package:flutter/material.dart';
import 'package:parentshield/config/constants.dart';

class BlockedOverlayScreen extends StatefulWidget {
  final String? appName;
  final String? reason;

  const BlockedOverlayScreen({
    Key? key,
    this.appName,
    this.reason,
  }) : super(key: key);

  @override
  State<BlockedOverlayScreen> createState() => _BlockedOverlayScreenState();
}

class _BlockedOverlayScreenState extends State<BlockedOverlayScreen> {
  bool _requestSent = false;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.navy,
                AppColors.navy.withOpacity(0.95),
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
                  const SizedBox(height: 60),
                  // Lock Icon
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock,
                        size: 96,
                        color: AppColors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Main Message
                  Text(
                    'This App is Locked',
                    style: AppTextStyles.headingMedium.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // App Name
                  if (widget.appName != null)
                    Text(
                      widget.appName!,
                      style: AppTextStyles.headingMedium.copyWith(
                        color: AppColors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 32),
                  // Reason Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.orange,
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Reason',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.white.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.reason ??
                              'Your parent restricted access to this app',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Reason Details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.orange.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getReasonIcon(),
                              color: AppColors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getReasonTitle(),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getReasonDescription(),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.white.withOpacity(0.8),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Request Access Button
                  if (!_requestSent)
                    ElevatedButton(
                      onPressed: _handleRequestAccess,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.send,
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
                  if (_requestSent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.teal.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: AppColors.teal,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Request sent to your parent',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.teal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Info Text
                  Text(
                    'Your parent can approve or deny your request from their device',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.white.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 60),
                  // Footer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.verified,
                          color: AppColors.orange,
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Protected by ParentShield',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Designed to help you stay safe',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.white.withOpacity(0.6),
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

  void _handleRequestAccess() {
    setState(() => _requestSent = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Access request sent to your parent'),
        backgroundColor: AppColors.teal,
        duration: const Duration(seconds: 3),
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _requestSent = false);
      }
    });
  }

  IconData _getReasonIcon() {
    if (widget.reason == null) return Icons.block;
    if (widget.reason!.contains('blocked')) return Icons.block;
    if (widget.reason!.contains('time')) return Icons.schedule;
    if (widget.reason!.contains('school')) return Icons.school;
    return Icons.block;
  }

  String _getReasonTitle() {
    if (widget.reason == null) return 'App Blocked';
    if (widget.reason!.contains('blocked')) return 'App Blocked by Parent';
    if (widget.reason!.contains('time')) return 'Time Limit Reached';
    if (widget.reason!.contains('school')) return 'School Hours Restriction';
    return 'App Blocked';
  }

  String _getReasonDescription() {
    if (widget.reason == null) {
      return 'Your parent has restricted access to this app. You can request access if you need it for a specific purpose.';
    }
    if (widget.reason!.contains('blocked')) {
      return 'This app is on the blocked list. Your parent thinks it\'s not appropriate for you right now.';
    }
    if (widget.reason!.contains('time')) {
      return 'You\'ve reached your daily screen time limit. Try again tomorrow!';
    }
    if (widget.reason!.contains('school')) {
      return 'This app is blocked during school hours to help you focus on your studies.';
    }
    return 'Your parent has restricted access to this app.';
  }
}
