import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/android_release_bundle_validator.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'danjjan-release-bundle-test-',
    );
  });

  tearDown(() {
    temporaryDirectory.deleteSync(recursive: true);
  });

  test('accepts 16 KB bundle and ELF alignment', () {
    final bundle = _writeBundle(
      temporaryDirectory,
      bundleAlignment: 2,
      elfAlignment: 0x4000,
    );

    final report = const AndroidReleaseBundleValidator().validate(bundle);

    expect(report.nativeLibraries, hasLength(1));
    expect(report.nativeLibraries.single.minimumLoadAlignmentBytes, 0x4000);
    expect(report.toJson()['bundlePageAlignment'], 'PAGE_ALIGNMENT_16K');
  });

  test('rejects a bundle configured for 4 KB ZIP alignment', () {
    final bundle = _writeBundle(
      temporaryDirectory,
      bundleAlignment: 1,
      elfAlignment: 0x4000,
    );

    expect(
      () => const AndroidReleaseBundleValidator().validate(bundle),
      throwsA(
        isA<AndroidReleaseBundleValidationException>().having(
          (error) => error.message,
          'message',
          contains('PAGE_ALIGNMENT_16K'),
        ),
      ),
    );
  });

  test('rejects a 64-bit native library with 4 KB ELF alignment', () {
    final bundle = _writeBundle(
      temporaryDirectory,
      bundleAlignment: 2,
      elfAlignment: 0x1000,
    );

    expect(
      () => const AndroidReleaseBundleValidator().validate(bundle),
      throwsA(
        isA<AndroidReleaseBundleValidationException>()
            .having((error) => error.message, 'path', contains('libexample.so'))
            .having(
              (error) => error.message,
              'alignment',
              contains('4096-byte'),
            ),
      ),
    );
  });

  test('accepts 4 KB ELF alignment for a 32-bit native library', () {
    final bundle = _writeBundle(
      temporaryDirectory,
      bundleAlignment: 2,
      elfAlignment: 0x1000,
      abi: 'armeabi-v7a',
      is64Bit: false,
    );

    final report = const AndroidReleaseBundleValidator().validate(bundle);

    expect(report.nativeLibraries, hasLength(1));
    expect(report.nativeLibraries.single.path, contains('armeabi-v7a'));
    expect(report.nativeLibraries.single.minimumLoadAlignmentBytes, 0x1000);
  });

  test('rejects a bundle without native libraries', () {
    final archive = Archive()
      ..addFile(
        ArchiveFile.bytes('BundleConfig.pb', _bundleConfig(alignment: 2)),
      );
    final bundle = File('${temporaryDirectory.path}/empty.aab')
      ..writeAsBytesSync(ZipEncoder().encodeBytes(archive));

    expect(
      () => const AndroidReleaseBundleValidator().validate(bundle),
      throwsA(
        isA<AndroidReleaseBundleValidationException>().having(
          (error) => error.message,
          'message',
          contains('no native libraries'),
        ),
      ),
    );
  });
}

File _writeBundle(
  Directory directory, {
  required int bundleAlignment,
  required int elfAlignment,
  String abi = 'arm64-v8a',
  bool is64Bit = true,
}) {
  final archive = Archive()
    ..addFile(
      ArchiveFile.bytes(
        'BundleConfig.pb',
        _bundleConfig(alignment: bundleAlignment),
      ),
    )
    ..addFile(
      ArchiveFile.bytes(
        'base/lib/$abi/libexample.so',
        is64Bit
            ? _elf64(alignment: elfAlignment)
            : _elf32(alignment: elfAlignment),
      ),
    );

  return File('${directory.path}/app-release.aab')
    ..writeAsBytesSync(ZipEncoder().encodeBytes(archive));
}

Uint8List _bundleConfig({required int alignment}) {
  final nativeLibraryConfig = <int>[0x08, 0x01, 0x10, alignment];
  final optimizations = <int>[
    0x12,
    nativeLibraryConfig.length,
    ...nativeLibraryConfig,
  ];
  return Uint8List.fromList(<int>[
    0x12,
    optimizations.length,
    ...optimizations,
  ]);
}

Uint8List _elf64({required int alignment}) {
  const elfHeaderSize = 64;
  const programHeaderSize = 56;
  final bytes = Uint8List(elfHeaderSize + programHeaderSize);
  final data = ByteData.sublistView(bytes);

  bytes.setAll(0, const <int>[0x7f, 0x45, 0x4c, 0x46]);
  bytes[4] = 2;
  bytes[5] = 1;
  bytes[6] = 1;
  data.setUint64(32, elfHeaderSize, Endian.little);
  data.setUint16(54, programHeaderSize, Endian.little);
  data.setUint16(56, 1, Endian.little);
  data.setUint32(elfHeaderSize, 1, Endian.little);
  data.setUint64(elfHeaderSize + 48, alignment, Endian.little);

  return bytes;
}

Uint8List _elf32({required int alignment}) {
  const elfHeaderSize = 52;
  const programHeaderSize = 32;
  final bytes = Uint8List(elfHeaderSize + programHeaderSize);
  final data = ByteData.sublistView(bytes);

  bytes.setAll(0, const <int>[0x7f, 0x45, 0x4c, 0x46]);
  bytes[4] = 1;
  bytes[5] = 1;
  bytes[6] = 1;
  data.setUint32(28, elfHeaderSize, Endian.little);
  data.setUint16(42, programHeaderSize, Endian.little);
  data.setUint16(44, 1, Endian.little);
  data.setUint32(elfHeaderSize, 1, Endian.little);
  data.setUint32(elfHeaderSize + 28, alignment, Endian.little);

  return bytes;
}
