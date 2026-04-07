import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

const Color _teal = Color(0xFF00B4D8);
const Color _navy = Color(0xFF0F1B2D);
const Color _orange = Color(0xFFFF6B35);
const Color _offWhite = Color(0xFFF0F4F8);
const Color _darkText = Color(0xFF1E293B);
const Color _midGray = Color(0xFF64748B);
const Color _lightGray = Color(0xFFE2E8F0);

class WeeklyUsageChart extends StatelessWidget {
  final List<int> dailyMinutes;
  final List<String> dayLabels;
  final int? todayIndex;

  const WeeklyUsageChart({
    Key? key,
    required this.dailyMinutes,
    required this.dayLabels,
    this.todayIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final maxValue = dailyMinutes.isEmpty ? 0 : dailyMinutes.reduce((a, b) => a > b ? a : b).toDouble();
    final adjustedMax = maxValue == 0 ? 60.0 : (maxValue * 1.1).ceilToDouble();

    final barGroups = List.generate(
      dailyMinutes.length,
      (index) => BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: dailyMinutes[index].toDouble(),
            color: todayIndex == index ? _orange : _teal,
            width: 12,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(6),
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Screen Time',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _darkText,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                maxY: adjustedMax,
                barGroups: barGroups,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: adjustedMax / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: _lightGray,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}m',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _midGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < dayLabels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              dayLabels[index],
                              style: const TextStyle(
                                fontSize: 12,
                                color: _midGray,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: _darkText.withOpacity(0.8),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final minutes = rod.toY.toInt();
                      final hours = minutes ~/ 60;
                      final mins = minutes % 60;
                      String time;
                      if (hours > 0) {
                        time = '${hours}h ${mins}m';
                      } else {
                        time = '${mins}m';
                      }
                      return BarTooltipItem(
                        time,
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppUsagePieChart extends StatelessWidget {
  final Map<String, int> appUsage;
  final int maxApps;

  const AppUsagePieChart({
    Key? key,
    required this.appUsage,
    this.maxApps = 5,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Sort by usage and take top apps
    final sortedApps = appUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topApps = sortedApps.take(maxApps).toList();
    final totalUsage = topApps.fold<int>(0, (sum, entry) => sum + entry.value);

    if (totalUsage == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            const Text(
              'App Usage',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _darkText,
              ),
            ),
            const SizedBox(height: 60),
            Text(
              'No usage data',
              style: const TextStyle(
                fontSize: 16,
                color: _midGray,
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      );
    }

    final colors = [_teal, _orange, _navy, Color(0xFF00D9FF), Color(0xFFFFA500)];
    final pieChartSections = List.generate(
      topApps.length,
      (index) => PieChartSectionData(
        color: colors[index % colors.length],
        value: topApps[index].value.toDouble(),
        title: '${((topApps[index].value / totalUsage) * 100).toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'App Usage',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _darkText,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: pieChartSections,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Column(
            children: List.generate(
              topApps.length,
              (index) {
                final appName = topApps[index].key;
                final usage = topApps[index].value;
                final percentage =
                    ((usage / totalUsage) * 100).toStringAsFixed(1);
                final hours = usage ~/ 60;
                final mins = usage % 60;
                String timeStr;
                if (hours > 0) {
                  timeStr = '${hours}h ${mins}m';
                } else {
                  timeStr = '${mins}m';
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colors[index % colors.length],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          appName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _darkText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$timeStr ($percentage%)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _midGray,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
