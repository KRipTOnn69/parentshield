import 'package:flutter/material.dart';
import 'package:parentshield/models/app_rule_model.dart';

const Color _teal = Color(0xFF00B4D8);
const Color _navy = Color(0xFF0F1B2D);
const Color _orange = Color(0xFFFF6B35);
const Color _offWhite = Color(0xFFF0F4F8);
const Color _darkText = Color(0xFF1E293B);
const Color _midGray = Color(0xFF64748B);
const Color _lightGray = Color(0xFFE2E8F0);

class AppTile extends StatefulWidget {
  final AppRule appRule;
  final ValueChanged<bool>? onBlockToggled;
  final ValueChanged<int>? onTimeLimitChanged;
  final VoidCallback? onScheduleTap;

  const AppTile({
    Key? key,
    required this.appRule,
    this.onBlockToggled,
    this.onTimeLimitChanged,
    this.onScheduleTap,
  }) : super(key: key);

  @override
  State<AppTile> createState() => _AppTileState();
}

class _AppTileState extends State<AppTile> {
  late bool _isExpanded;
  late int _timeLimitMinutes;

  @override
  void initState() {
    super.initState();
    _isExpanded = false;
    _timeLimitMinutes = widget.appRule.dailyLimitMinutes ?? 0;
  }

  @override
  void didUpdateWidget(AppTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appRule.packageName != widget.appRule.packageName) {
      _timeLimitMinutes = widget.appRule.dailyLimitMinutes ?? 0;
    }
  }

  String _formatMinutesToTime(int minutes) {
    if (minutes == 0) return 'No limit';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) {
      return '${hours}h ${mins}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${mins}m';
    }
  }

  double _getUsagePercentage() {
    if (widget.appRule.dailyLimitMinutes == null ||
        widget.appRule.dailyLimitMinutes == 0) {
      return 0;
    }
    final usage =
        widget.appRule.usedTodayMinutes.toDouble();
    final limit = widget.appRule.dailyLimitMinutes!.toDouble();
    return (usage / limit).clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final usagePercentage = _getUsagePercentage();
    final usageMinutes = widget.appRule.usedTodayMinutes;

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 56,
                      height: 56,
                      color: _lightGray,
                      child: Icon(
                              Icons.apps,
                              color: _midGray,
                              size: 28,
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.appRule.appName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _darkText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.appRule.packageName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _midGray,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.appRule.isBlocked ? 'Blocked' : 'Allowed',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: widget.appRule.isBlocked
                              ? _orange
                              : _teal,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Switch(
                        value: widget.appRule.isBlocked,
                        onChanged: (value) {
                          widget.onBlockToggled?.call(value);
                        },
                        activeColor: _orange,
                        inactiveThumbColor: _teal,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_isExpanded) ...[
              const Divider(height: 1, color: _lightGray),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Daily Time Limit',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _darkText,
                          ),
                        ),
                        Text(
                          _formatMinutesToTime(_timeLimitMinutes),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _teal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 6,
                        thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: 10,
                        ),
                        overlayShape: RoundSliderOverlayShape(
                          overlayRadius: 16,
                        ),
                      ),
                      child: Slider(
                        value: _timeLimitMinutes.toDouble(),
                        min: 0,
                        max: 240,
                        divisions: 48,
                        activeColor: _teal,
                        inactiveColor: _lightGray,
                        onChanged: (value) {
                          setState(() {
                            _timeLimitMinutes = value.toInt();
                          });
                          widget.onTimeLimitChanged
                              ?.call(_timeLimitMinutes);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: usagePercentage,
                        minHeight: 8,
                        backgroundColor: _lightGray,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          usagePercentage > 0.8
                              ? _orange
                              : _teal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Used: ${usageMinutes}m',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _midGray,
                          ),
                        ),
                        Text(
                          'Today',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _midGray,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: widget.onScheduleTap,
                        icon: const Icon(Icons.schedule),
                        label: const Text('Set Schedule'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _teal,
                          side: const BorderSide(color: _teal),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
