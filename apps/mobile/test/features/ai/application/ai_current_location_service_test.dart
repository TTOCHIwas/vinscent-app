import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/ai/application/ai_current_location_service.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('desktop platforms fall back without requesting location', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    final location = await const GeolocatorAiCurrentLocationService()
        .getCurrentLocation();

    expect(location, isNull);
  });
}
