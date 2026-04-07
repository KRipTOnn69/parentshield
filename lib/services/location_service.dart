import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;

class LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() {
    return _instance;
  }

  LocationService._internal();

  static const int _distanceFilter = 10; // meters
  static const LocationAccuracy _accuracy = LocationAccuracy.best;

  // ======================= LOCATION RETRIEVAL =======================

  /// Get current device location
  Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await checkPermission();
      if (!hasPermission) {
        throw Exception('Location permission not granted');
      }

      final isLocationServiceEnabled =
          await Geolocator.isLocationServiceEnabled();
      if (!isLocationServiceEnabled) {
        throw Exception('Location service is disabled');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );

      return position;
    } on LocationServiceDisabledException {
      throw Exception('Location service is disabled on this device');
    } on PermissionDeniedException {
      throw Exception('Location permission denied');
    } catch (e) {
      throw Exception('Failed to get current location: ${e.toString()}');
    }
  }

  /// Stream location updates in real-time
  Stream<Position> streamLocation() {
    try {
      return Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: _accuracy,
          distanceFilter: _distanceFilter,
          timeLimit: const Duration(seconds: 30),
        ),
      ).handleError((e) {
        throw Exception('Location stream error: ${e.toString()}');
      });
    } catch (e) {
      throw Exception('Failed to stream location: ${e.toString()}');
    }
  }

  // ======================= GEOFENCE OPERATIONS =======================

  /// Check if location is within geofence
  bool checkGeofence(
    double latitude,
    double longitude,
    double centerLatitude,
    double centerLongitude,
    double radiusMeters,
  ) {
    try {
      if (latitude == 0 ||
          longitude == 0 ||
          centerLatitude == 0 ||
          centerLongitude == 0) {
        throw Exception('Invalid coordinates provided');
      }

      if (radiusMeters <= 0) {
        throw Exception('Radius must be greater than 0');
      }

      final distance = calculateDistance(
        latitude,
        longitude,
        centerLatitude,
        centerLongitude,
      );

      return distance <= radiusMeters;
    } catch (e) {
      throw Exception('Geofence check failed: ${e.toString()}');
    }
  }

  /// Calculate distance between two coordinates using Haversine formula
  double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    try {
      if (lat1 == 0 || lng1 == 0 || lat2 == 0 || lng2 == 0) {
        throw Exception('Invalid coordinates provided');
      }

      const earthRadiusMeters = 6371000.0;

      final dLat = _toRadians(lat2 - lat1);
      final dLng = _toRadians(lng2 - lng1);

      final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(_toRadians(lat1)) *
              math.cos(_toRadians(lat2)) *
              math.sin(dLng / 2) *
              math.sin(dLng / 2);

      final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      final distance = earthRadiusMeters * c;

      return distance;
    } catch (e) {
      throw Exception('Distance calculation failed: ${e.toString()}');
    }
  }

  // ======================= PERMISSION MANAGEMENT =======================

  /// Request location permission
  Future<bool> requestPermission() async {
    try {
      final status = await Geolocator.requestPermission();

      return status == LocationPermission.whileInUse ||
          status == LocationPermission.always;
    } catch (e) {
      throw Exception('Failed to request location permission: ${e.toString()}');
    }
  }

  /// Check if location permission is granted
  Future<bool> checkPermission() async {
    try {
      final status = await Geolocator.checkPermission();

      if (status == LocationPermission.denied) {
        return false;
      }

      if (status == LocationPermission.deniedForever) {
        return false;
      }

      if (status == LocationPermission.whileInUse ||
          status == LocationPermission.always) {
        return true;
      }

      return false;
    } catch (e) {
      throw Exception('Failed to check location permission: ${e.toString()}');
    }
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      throw Exception('Failed to open location settings: ${e.toString()}');
    }
  }

  // ======================= HELPER METHODS =======================

  /// Convert degrees to radians
  double _toRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  /// Validate coordinates format
  bool _isValidCoordinate(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  /// Get location status string
  Future<String> getLocationStatusString() async {
    try {
      final isEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isEnabled) {
        return 'Location service disabled';
      }

      final permission = await Geolocator.checkPermission();
      switch (permission) {
        case LocationPermission.always:
          return 'Always enabled';
        case LocationPermission.whileInUse:
          return 'Enabled while in use';
        case LocationPermission.denied:
          return 'Permission denied';
        case LocationPermission.deniedForever:
          return 'Permission permanently denied';
        case LocationPermission.unableToDetermine:
          return 'Unable to determine';
      }
    } catch (e) {
      return 'Error checking status';
    }
  }
}
