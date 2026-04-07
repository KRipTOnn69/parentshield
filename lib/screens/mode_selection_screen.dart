import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentshield/config/constants.dart';

class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({Key? key}) : super(key: key);

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {
  @override
  void initState() {
    super.initState();
    _checkChildMode();
  }

  Future<void> _checkChildMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isPaired = prefs.getBool('is_paired') ?? false;
    if (isPaired && mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/child/status', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 40.0,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // Shield Icon
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.teal.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.verified_user,
                            size: 80,
                            color: AppColors.teal,
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Title
                        Text(
                          'ParentShield',
                          style: AppTextStyles.headingXL.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Tagline
                        Text(
                          'Protecting your family, building trust',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.offWhite,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 60),
                        // Parent Card
                        _ModeCard(
                          title: "I'm a Parent",
                          subtitle: 'Manage and monitor',
                          icon: Icons.shield,
                          color: AppColors.teal,
                          onTap: () => Navigator.of(context).pushNamed('/login'),
                        ),
                        const SizedBox(height: 20),
                        // Child Card
                        _ModeCard(
                          title: "I'm a Child",
                          subtitle: 'Set up parental control',
                          icon: Icons.child_care,
                          color: AppColors.orange,
                          onTap: () =>
                              Navigator.of(context).pushNamed('/child/pairing'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Footer
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Safe browsing for a safer future',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.midGray,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: color,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: AppTextStyles.headingMedium.copyWith(
                color: AppColors.darkText,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.midGray,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Get Started',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: color,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
