import 'package:flutter_test/flutter_test.dart';

import '../../tool/measure_android_cold_start.dart';

void main() {
  test('parses successful am start timing output', () {
    final result = parseAmStartOutput('''
Starting: Intent
Status: ok
LaunchState: COLD
Activity: com.vinscent.vinscent/.MainActivity
TotalTime: 842
WaitTime: 849
Complete
''');

    expect(result.totalTimeMs, 842);
    expect(result.waitTimeMs, 849);
    expect(result.launchState, 'COLD');
  });

  test('rejects failed or incomplete startup output', () {
    expect(
      () => parseAmStartOutput('Status: timeout\nTotalTime: 100'),
      throwsFormatException,
    );
    expect(
      () => parseAmStartOutput('Status: ok\nTotalTime: 100'),
      throwsFormatException,
    );
  });

  test('keeps only authorized connected Android devices', () {
    expect(
      parseConnectedDevices('''
List of devices attached
emulator-5554	device product:sdk model:sdk transport_id:1
R3CT30ABC	unauthorized usb:1-1 transport_id:2
offline-1	offline

'''),
      ['emulator-5554'],
    );
  });

  test('parses installed version, target SDK and debug state', () {
    final metadata = parseInstalledPackageMetadata('''
Package [com.vinscent.vinscent] (123):
  versionCode=42 minSdk=24 targetSdk=36
  versionName=1.0.0
  flags=[ HAS_CODE ALLOW_CLEAR_USER_DATA ]
''');

    expect(metadata['versionName'], '1.0.0');
    expect(metadata['versionCode'], 42);
    expect(metadata['targetSdk'], 36);
    expect(metadata['debuggable'], isFalse);
  });

  test('summarizes ten measurements with nearest-rank percentiles', () {
    final summary = summarizeMeasurements([
      1000,
      900,
      800,
      700,
      600,
      500,
      400,
      300,
      200,
      100,
    ]);

    expect(summary, {'min': 100, 'p50': 500, 'p90': 900, 'max': 1000});
  });

  test('requires a destination and at least ten measured runs', () {
    expect(
      () => AndroidColdStartOptions.parse(const []),
      throwsA(isA<UsageException>()),
    );
    expect(
      () => AndroidColdStartOptions.parse(const [
        '--output',
        'result.json',
        '--runs',
        '9',
      ]),
      throwsA(isA<UsageException>()),
    );

    final options = AndroidColdStartOptions.parse(const [
      '--output',
      'result.json',
      '--runs',
      '12',
      '--device',
      'device-1',
    ]);
    expect(options.outputPath, 'result.json');
    expect(options.runCount, 12);
    expect(options.deviceId, 'device-1');
  });
}
