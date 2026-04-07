import 'package:flutter/material.dart';

const Color _teal = Color(0xFF00B4D8);
const Color _navy = Color(0xFF0F1B2D);
const Color _orange = Color(0xFFFF6B35);
const Color _offWhite = Color(0xFFF0F4F8);
const Color _darkText = Color(0xFF1E293B);
const Color _midGray = Color(0xFF64748B);
const Color _lightGray = Color(0xFFE2E8F0);

class SafeZone {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final bool isActive;

  SafeZone({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.isActive,
  });

  SafeZone copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    int? radiusMeters,
    bool? isActive,
  }) {
    return SafeZone(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      isActive: isActive ?? this.isActive,
    );
  }
}

class SafeZoneCard extends StatefulWidget {
  final SafeZone zone;
  final ValueChanged<bool>? onActiveChanged;
  final VoidCallback? onDelete;

  const SafeZoneCard({
    Key? key,
    required this.zone,
    this.onActiveChanged,
    this.onDelete,
  }) : super(key: key);

  @override
  State<SafeZoneCard> createState() => _SafeZoneCardState();
}

class _SafeZoneCardState extends State<SafeZoneCard> {
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _isActive = widget.zone.isActive;
  }

  @override
  void didUpdateWidget(SafeZoneCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zone.id != widget.zone.id) {
      _isActive = widget.zone.isActive;
    }
  }

  IconData _getZoneIcon(String zoneName) {
    final lowerName = zoneName.toLowerCase();

    if (lowerName.contains('home')) {
      return Icons.home;
    } else if (lowerName.contains('school')) {
      return Icons.school;
    } else if (lowerName.contains('work') || lowerName.contains('office')) {
      return Icons.business;
    } else if (lowerName.contains('park') || lowerName.contains('gym')) {
      return Icons.sports_bar;
    } else {
      return Icons.location_on;
    }
  }

  String _formatRadius(int meters) {
    if (meters < 1000) {
      return '${meters}m';
    } else {
      final km = (meters / 1000).toStringAsFixed(1);
      return '${km}km';
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _getZoneIcon(widget.zone.name);
    final radiusStr = _formatRadius(widget.zone.radiusMeters);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: _isActive ? _teal : _lightGray,
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _isActive
                        ? _teal.withOpacity(0.15)
                        : _lightGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: _isActive ? _teal : _midGray,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.zone.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _darkText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: _midGray,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.zone.address,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _midGray,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: _isActive,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                    widget.onActiveChanged?.call(value);
                  },
                  activeColor: _teal,
                  inactiveThumbColor: _midGray,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _offWhite,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.radio_button_unchecked,
                        size: 14,
                        color: _teal,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Radius: $radiusStr',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _teal,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onDelete,
                  child: Icon(
                    Icons.delete_outline,
                    color: _orange,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
