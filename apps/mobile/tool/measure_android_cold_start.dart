import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const _packageName = 'com.vinscent.vinscent';
const _activityName = '.MainActivity';
const _minimumRunCount = 10;
const _commandTimeout = Duration(seconds: 20);

Future<void> main(List<String> arguments) async {
  try {
    final options = AndroidColdStartOptions.parse(arguments);
    if (options.showHelp) {
      stdout.writeln(AndroidColdStartOptions.usage);
      return;
    }

    final outputFile = File(options.outputPath!);
    if (outputFile.existsSync()) {
      throw StateError('Evidence already exists: ${outputFile.path}');
    }

    final commandRunner = CommandRunner(timeout: _commandTimeout);
    final adb = AdbClient(
      executable: options.adbExecutable,
      commandRunner: commandRunner,
    );
    final deviceId = options.deviceId ?? await adb.requireSingleDevice();
    final packageDump = await adb.packageDump(deviceId);
    final mobileDirectory = File.fromUri(Platform.script).parent.parent;
    final commitSha = (await commandRunner.run('git', [
      '-C',
      mobileDirectory.path,
      'rev-parse',
      'HEAD',
    ])).stdout.trim();
    final appVersion = _readAppVersion(
      File('${mobileDirectory.path}${Platform.pathSeparator}pubspec.yaml'),
    );
    final installedPackage = parseInstalledPackageMetadata(packageDump);
    validateInstalledReleasePackage(
      installedPackage,
      expectedAppVersion: appVersion,
    );

    stdout.writeln('Discarding one cold-start warm-up run...');
    final warmUp = await adb.measureColdStart(deviceId);
    final samples = <AmStartMeasurement>[];
    for (var index = 0; index < options.runCount; index += 1) {
      stdout.writeln(
        'Measuring cold start ${index + 1}/${options.runCount}...',
      );
      samples.add(await adb.measureColdStart(deviceId));
    }
    await adb.forceStop(deviceId);

    final report = <String, Object?>{
      'schemaVersion': 1,
      'recordedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'commitSha': commitSha,
      'appVersion': appVersion,
      'packageName': _packageName,
      'activityName': _activityName,
      'device': <String, Object?>{
        'id': deviceId,
        'model': await adb.property(deviceId, 'ro.product.model'),
        'androidVersion': await adb.property(
          deviceId,
          'ro.build.version.release',
        ),
        'apiLevel': int.tryParse(
          await adb.property(deviceId, 'ro.build.version.sdk'),
        ),
      },
      'installedPackage': installedPackage,
      'measurement': <String, Object?>{
        'method': 'adb shell am start -W after am force-stop',
        'discardedWarmUp': warmUp.toJson(),
        'runCount': samples.length,
        'totalTimeMs': summarizeMeasurements(
          samples.map((sample) => sample.totalTimeMs),
        ),
        'waitTimeMs': summarizeMeasurements(
          samples.map((sample) => sample.waitTimeMs),
        ),
        'samples': samples.map((sample) => sample.toJson()).toList(),
      },
    };

    outputFile.parent.createSync(recursive: true);
    outputFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(report),
      flush: true,
    );
    stdout.writeln('Android cold-start evidence saved to ${outputFile.path}');
  } on UsageException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(AndroidColdStartOptions.usage);
    exitCode = 64;
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

class AndroidColdStartOptions {
  const AndroidColdStartOptions({
    required this.outputPath,
    required this.deviceId,
    required this.runCount,
    required this.adbExecutable,
    required this.showHelp,
  });

  factory AndroidColdStartOptions.parse(List<String> arguments) {
    String? outputPath;
    String? deviceId;
    var runCount = _minimumRunCount;
    var adbExecutable = 'adb';
    var showHelp = false;

    for (var index = 0; index < arguments.length; index += 1) {
      final argument = arguments[index];
      if (argument == '--help' || argument == '-h') {
        showHelp = true;
        continue;
      }

      if (index + 1 >= arguments.length) {
        throw UsageException('Missing value for $argument.');
      }
      final value = arguments[index + 1];
      index += 1;

      switch (argument) {
        case '--output':
          outputPath = value;
        case '--device':
          deviceId = value;
        case '--runs':
          runCount =
              int.tryParse(value) ??
              (throw UsageException('--runs must be an integer.'));
        case '--adb':
          adbExecutable = value;
        default:
          throw UsageException('Unknown argument: $argument');
      }
    }

    if (!showHelp && (outputPath == null || outputPath.trim().isEmpty)) {
      throw UsageException('--output is required.');
    }
    if (runCount < _minimumRunCount) {
      throw UsageException('--runs must be at least $_minimumRunCount.');
    }

    return AndroidColdStartOptions(
      outputPath: outputPath,
      deviceId: deviceId,
      runCount: runCount,
      adbExecutable: adbExecutable,
      showHelp: showHelp,
    );
  }

  static const usage = '''
Usage:
  dart run tool/measure_android_cold_start.dart --output <evidence.json>
      [--device <adb-device-id>] [--runs <count>] [--adb <path>]

The tool discards one warm-up run, records at least 10 cold starts, and exits.
''';

  final String? outputPath;
  final String? deviceId;
  final int runCount;
  final String adbExecutable;
  final bool showHelp;
}

class AdbClient {
  const AdbClient({required this.executable, required this.commandRunner});

  final String executable;
  final CommandRunner commandRunner;

  Future<String> requireSingleDevice() async {
    final result = await commandRunner.run(executable, const ['devices']);
    final devices = parseConnectedDevices(result.stdout);
    if (devices.length != 1) {
      throw StateError(
        'Expected exactly one authorized Android device; found '
        '${devices.length}. Pass --device when more than one is connected.',
      );
    }
    return devices.single;
  }

  Future<String> property(String deviceId, String propertyName) async {
    final result = await _runForDevice(deviceId, [
      'shell',
      'getprop',
      propertyName,
    ]);
    return result.stdout.trim();
  }

  Future<String> packageDump(String deviceId) async {
    final result = await _runForDevice(deviceId, [
      'shell',
      'dumpsys',
      'package',
      _packageName,
    ]);
    if (!result.stdout.contains('Package [$_packageName]')) {
      throw StateError('$_packageName is not installed on $deviceId.');
    }
    return result.stdout;
  }

  Future<AmStartMeasurement> measureColdStart(String deviceId) async {
    await forceStop(deviceId);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final result = await _runForDevice(deviceId, [
      'shell',
      'am',
      'start',
      '-W',
      '$_packageName/$_activityName',
    ]);
    return parseAmStartOutput(result.stdout);
  }

  Future<void> forceStop(String deviceId) async {
    await _runForDevice(deviceId, ['shell', 'am', 'force-stop', _packageName]);
  }

  Future<CommandResult> _runForDevice(String deviceId, List<String> arguments) {
    return commandRunner.run(executable, ['-s', deviceId, ...arguments]);
  }
}

class CommandRunner {
  const CommandRunner({required this.timeout});

  final Duration timeout;

  Future<CommandResult> run(String executable, List<String> arguments) async {
    final process = await Process.start(executable, arguments);
    final stdoutResult = process.stdout.transform(utf8.decoder).join();
    final stderrResult = process.stderr.transform(utf8.decoder).join();

    late final int processExitCode;
    try {
      processExitCode = await process.exitCode.timeout(timeout);
    } on TimeoutException {
      process.kill();
      await process.exitCode.timeout(
        const Duration(seconds: 2),
        onTimeout: () => -1,
      );
      throw TimeoutException(
        '$executable exceeded the ${timeout.inSeconds}-second command limit.',
        timeout,
      );
    }

    final result = CommandResult(
      exitCode: processExitCode,
      stdout: await stdoutResult,
      stderr: await stderrResult,
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        executable,
        arguments,
        result.stderr.trim(),
        result.exitCode,
      );
    }
    return result;
  }
}

class CommandResult {
  const CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

class AmStartMeasurement {
  const AmStartMeasurement({
    required this.totalTimeMs,
    required this.waitTimeMs,
    required this.launchState,
  });

  final int totalTimeMs;
  final int waitTimeMs;
  final String? launchState;

  Map<String, Object?> toJson() => <String, Object?>{
    'totalTimeMs': totalTimeMs,
    'waitTimeMs': waitTimeMs,
    'launchState': launchState,
  };
}

AmStartMeasurement parseAmStartOutput(String output) {
  final fields = <String, String>{};
  for (final line in const LineSplitter().convert(output)) {
    final match = RegExp(r'^\s*([A-Za-z]+):\s*(.*?)\s*$').firstMatch(line);
    if (match != null) {
      fields[match.group(1)!] = match.group(2)!;
    }
  }

  if (fields['Status'] != 'ok') {
    throw FormatException(
      'Android activity launch did not complete successfully.',
      output,
    );
  }

  final totalTimeMs = int.tryParse(fields['TotalTime'] ?? '');
  final waitTimeMs = int.tryParse(fields['WaitTime'] ?? '');
  if (totalTimeMs == null || waitTimeMs == null) {
    throw FormatException('Missing Android startup timing fields.', output);
  }

  return AmStartMeasurement(
    totalTimeMs: totalTimeMs,
    waitTimeMs: waitTimeMs,
    launchState: fields['LaunchState'],
  );
}

List<String> parseConnectedDevices(String output) {
  return const LineSplitter()
      .convert(output)
      .skip(1)
      .map((line) => line.trim().split(RegExp(r'\s+')))
      .where((fields) => fields.length >= 2 && fields[1] == 'device')
      .map((fields) => fields.first)
      .toList(growable: false);
}

Map<String, Object?> parseInstalledPackageMetadata(String packageDump) {
  String? valueFor(String name) {
    return RegExp(
      '(?:^|\\s)${RegExp.escape(name)}=(\\S+)',
      multiLine: true,
    ).firstMatch(packageDump)?.group(1);
  }

  return <String, Object?>{
    'versionName': valueFor('versionName'),
    'versionCode': int.tryParse(valueFor('versionCode') ?? ''),
    'targetSdk': int.tryParse(valueFor('targetSdk') ?? ''),
    'debuggable': RegExp(
      r'^\s*flags=\[[^\]]*\bDEBUGGABLE\b',
      multiLine: true,
    ).hasMatch(packageDump),
  };
}

void validateInstalledReleasePackage(
  Map<String, Object?> metadata, {
  required String? expectedAppVersion,
}) {
  if (expectedAppVersion == null || expectedAppVersion.trim().isEmpty) {
    throw StateError('Unable to read the expected app version.');
  }

  final installedVersionName = metadata['versionName'];
  final expectedVersionName = expectedAppVersion.split('+').first;
  if (installedVersionName != expectedVersionName) {
    throw StateError(
      'Installed version does not match the current source version.',
    );
  }

  final versionCode = metadata['versionCode'];
  if (versionCode is! int || versionCode <= 0) {
    throw StateError('Installed package has no valid version code.');
  }

  final targetSdk = metadata['targetSdk'];
  if (targetSdk is! int || targetSdk < 36) {
    throw StateError(
      'Installed release candidate must target SDK 36 or later.',
    );
  }

  if (metadata['debuggable'] != false) {
    throw StateError(
      'Cold-start release evidence requires a non-debuggable build.',
    );
  }
}

Map<String, int> summarizeMeasurements(Iterable<int> measurements) {
  final sorted = measurements.toList()..sort();
  if (sorted.isEmpty) {
    throw ArgumentError.value(
      measurements,
      'measurements',
      'must not be empty',
    );
  }

  return <String, int>{
    'min': sorted.first,
    'p50': nearestRankPercentile(sorted, 0.50),
    'p90': nearestRankPercentile(sorted, 0.90),
    'max': sorted.last,
  };
}

int nearestRankPercentile(List<int> sortedMeasurements, double percentile) {
  if (sortedMeasurements.isEmpty) {
    throw ArgumentError.value(
      sortedMeasurements,
      'sortedMeasurements',
      'must not be empty',
    );
  }
  if (percentile <= 0 || percentile > 1) {
    throw RangeError.range(percentile, 0, 1, 'percentile');
  }

  final index = math.max(
    0,
    math.min(
      sortedMeasurements.length - 1,
      (percentile * sortedMeasurements.length).ceil() - 1,
    ),
  );
  return sortedMeasurements[index];
}

String? _readAppVersion(File pubspec) {
  if (!pubspec.existsSync()) {
    return null;
  }
  final match = RegExp(
    r'^version:\s*(\S+)',
    multiLine: true,
  ).firstMatch(pubspec.readAsStringSync());
  return match?.group(1);
}

class UsageException implements Exception {
  const UsageException(this.message);

  final String message;
}
