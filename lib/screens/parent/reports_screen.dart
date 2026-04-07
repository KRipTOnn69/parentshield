import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parentshield/config/constants.dart';
import 'package:parentshield/providers/child_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isToday = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChildProvider>().loadReports();
    });
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
          'Reports',
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
              // Date Selector
              Row(
                children: [
                  Expanded(
                    child: _DateButton(
                      label: 'Today',
                      isSelected: _isToday,
                      onTap: () => setState(() => _isToday = true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateButton(
                      label: 'This Week',
                      isSelected: !_isToday,
                      onTap: () => setState(() => _isToday = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Total Screen Time Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.teal.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Total Screen Time',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.midGray,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isToday ? '2h 34m' : '14h 52m',
                      style: AppTextStyles.headingXL.copyWith(
                        color: AppColors.teal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: 0.45,
                          backgroundColor: AppColors.teal.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.teal,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Screen time target: ${_isToday ? '4h' : '20h'}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.midGray,
                          ),
                        ),
                        Text(
                          'On Track',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.teal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Top Apps Usage
              Text(
                'Top Apps',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.darkText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _AppUsageChart(),
              const SizedBox(height: 24),
              // Blocked Attempts
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
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
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.orange.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.block,
                            color: AppColors.orange,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Blocked Attempts',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.midGray,
                              ),
                            ),
                            Text(
                              _isToday ? '3' : '17',
                              style: AppTextStyles.headingMedium.copyWith(
                                color: AppColors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _isToday ? '+1 today' : '+3 this week',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Recent Blocked Attempts
              Text(
                'Recent Blocked Attempts',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.darkText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _BlockedAttemptTile(app: 'TikTok', reason: 'Restricted app', time: '2:45 PM'),
              const SizedBox(height: 12),
              _BlockedAttemptTile(app: 'YouTube', reason: 'Time limit exceeded', time: '1:30 PM'),
              const SizedBox(height: 12),
              _BlockedAttemptTile(app: 'Discord', reason: 'School hours', time: '10:15 AM'),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DateButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.teal : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.teal
                : AppColors.midGray.withOpacity(0.2),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isSelected ? AppColors.white : AppColors.darkText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _AppUsageChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final apps = [
      {'name': 'YouTube', 'time': 45, 'color': AppColors.orange},
      {'name': 'Instagram', 'time': 35, 'color': AppColors.teal},
      {'name': 'Discord', 'time': 30, 'color': AppColors.navy},
      {'name': 'Minecraft', 'time': 44, 'color': AppColors.midGray},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.midGray.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: apps
            .map((app) {
              final maxTime = 50;
              final percentage = (app['time'] as int) / maxTime;

              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: app['color'] as Color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            app['name'] as String,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.darkText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${app['time']}m',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.midGray,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      minHeight: 6,
                      backgroundColor:
                          (app['color'] as Color).withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        app['color'] as Color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            })
            .toList(),
      ),
    );
  }
}

class _BlockedAttemptTile extends StatelessWidget {
  final String app;
  final String reason;
  final String time;

  const _BlockedAttemptTile({
    required this.app,
    required this.reason,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.midGray.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.block,
              color: AppColors.orange,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.darkText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reason,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.midGray,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.midGray,
            ),
          ),
        ],
      ),
    );
  }
}

