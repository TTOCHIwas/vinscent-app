import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

final aiCurrentLocationServiceProvider = Provider<AiCurrentLocationService>(
  (ref) => const GeolocatorAiCurrentLocationService(),
);

class AiCurrentLocation {
  const AiCurrentLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

abstract interface class AiCurrentLocationService {
  Future<AiCurrentLocation?> getCurrentLocation();
}

class GeolocatorAiCurrentLocationService implements AiCurrentLocationService {
  const GeolocatorAiCurrentLocationService();

  @override
  Future<AiCurrentLocation?> getCurrentLocation() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return null;
    }

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 6),
        ),
      );
      return AiCurrentLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on Object {
      return null;
    }
  }
}
