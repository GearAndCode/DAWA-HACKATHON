import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class DawaLocation {
  final double latitude;
  final double longitude;
  final String label;
  final String address;
  final bool isActualGps;

  const DawaLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.address,
    this.isActualGps = false,
  });
}

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  // Fictional fallback locations in Lahore for manual selection
  static const List<DawaLocation> manualLocations = [
    DawaLocation(
      label: 'Gulberg III',
      address: 'Main Boulevard, Gulberg III, Lahore',
      latitude: 31.5204,
      longitude: 74.3587,
    ),
    DawaLocation(
      label: 'Model Town',
      address: 'Bank Square, Model Town, Lahore',
      latitude: 31.4820,
      longitude: 74.3160,
    ),
    DawaLocation(
      label: 'DHA Phase 5',
      address: 'Sector C Commercial, DHA Phase 5, Lahore',
      latitude: 31.4673,
      longitude: 74.4024,
    ),
    DawaLocation(
      label: 'Johar Town',
      address: 'Block G-4, Johar Town, Lahore',
      latitude: 31.4697,
      longitude: 74.2728,
    ),
  ];

  final ValueNotifier<DawaLocation?> currentLocation =
      ValueNotifier<DawaLocation?>(null);
  final ValueNotifier<bool> permissionRequested = ValueNotifier<bool>(false);

  Future<LocationPermissionResult> requestRealLocation() async {
    permissionRequested.value = true;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationPermissionResult.serviceDisabled;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationPermissionResult.denied;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationPermissionResult.permanentlyDenied;
      }

      // Permission granted - get actual device coordinates
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final loc = DawaLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        label: 'Current Location',
        address: 'Lat: ${pos.latitude.toStringAsFixed(4)}, Lon: ${pos.longitude.toStringAsFixed(4)}',
        isActualGps: true,
      );

      currentLocation.value = loc;
      return LocationPermissionResult.granted;
    } catch (e) {
      debugPrint('Error getting location: $e');
      return LocationPermissionResult.unavailable;
    }
  }

  void setManualLocation(DawaLocation loc) {
    currentLocation.value = loc;
  }
}

enum LocationPermissionResult {
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled,
  unavailable,
}
