import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

const _requiredPageAlignment = 16 * 1024;

class AndroidReleaseBundleValidationException implements Exception {
  const AndroidReleaseBundleValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AndroidNativeLibraryAlignment {
  const AndroidNativeLibraryAlignment({
    required this.path,
    required this.minimumLoadAlignmentBytes,
  });

  final String path;
  final int minimumLoadAlignmentBytes;

  Map<String, Object> toJson() => <String, Object>{
    'path': path,
    'minimumLoadAlignmentBytes': minimumLoadAlignmentBytes,
  };
}

class AndroidReleaseBundleReport {
  const AndroidReleaseBundleReport({required this.nativeLibraries});

  final List<AndroidNativeLibraryAlignment> nativeLibraries;

  Map<String, Object> toJson() => <String, Object>{
    'bundlePageAlignment': 'PAGE_ALIGNMENT_16K',
    'nativeLibraryCount': nativeLibraries.length,
    'nativeLibraries': nativeLibraries
        .map((library) => library.toJson())
        .toList(growable: false),
  };
}

class AndroidReleaseBundleValidator {
  const AndroidReleaseBundleValidator();

  AndroidReleaseBundleReport validate(File bundle) {
    if (!bundle.existsSync() || bundle.lengthSync() == 0) {
      throw AndroidReleaseBundleValidationException(
        'Android App Bundle does not exist or is empty: ${bundle.path}',
      );
    }

    final input = InputFileStream(bundle.path);
    try {
      final archive = ZipDecoder().decodeStream(input);
      _validateBundlePageAlignment(archive);

      final nativeEntries =
          archive.files
              .where(
                (entry) =>
                    entry.isFile &&
                    entry.name.contains('/lib/') &&
                    entry.name.endsWith('.so'),
              )
              .toList(growable: false)
            ..sort((left, right) => left.name.compareTo(right.name));

      if (nativeEntries.isEmpty) {
        throw const AndroidReleaseBundleValidationException(
          'Android App Bundle contains no native libraries to validate.',
        );
      }

      final libraries = nativeEntries
          .map((entry) {
            final bytes = entry.readBytes();
            if (bytes == null || bytes.isEmpty) {
              throw AndroidReleaseBundleValidationException(
                'Native library is empty: ${entry.name}',
              );
            }

            final minimumAlignment = _minimumLoadAlignment(
              bytes,
              path: entry.name,
            );
            if (minimumAlignment < _requiredPageAlignment ||
                minimumAlignment % _requiredPageAlignment != 0) {
              throw AndroidReleaseBundleValidationException(
                '${entry.name} has $minimumAlignment-byte ELF LOAD alignment; '
                'at least $_requiredPageAlignment-byte alignment is required.',
              );
            }

            return AndroidNativeLibraryAlignment(
              path: entry.name,
              minimumLoadAlignmentBytes: minimumAlignment,
            );
          })
          .toList(growable: false);

      return AndroidReleaseBundleReport(nativeLibraries: libraries);
    } on AndroidReleaseBundleValidationException {
      rethrow;
    } on Object catch (error) {
      throw AndroidReleaseBundleValidationException(
        'Unable to validate Android App Bundle: $error',
      );
    } finally {
      input.closeSync();
    }
  }

  void _validateBundlePageAlignment(Archive archive) {
    final configEntry = archive.findFile('BundleConfig.pb');
    final configBytes = configEntry?.readBytes();
    if (configBytes == null || configBytes.isEmpty) {
      throw const AndroidReleaseBundleValidationException(
        'Android App Bundle is missing BundleConfig.pb.',
      );
    }

    final optimizations = _ProtoMessage(configBytes).lengthDelimited(2);
    final nativeLibraries = optimizations == null
        ? null
        : _ProtoMessage(optimizations).lengthDelimited(2);
    final nativeConfig = nativeLibraries == null
        ? null
        : _ProtoMessage(nativeLibraries);
    final enabled = nativeConfig?.varint(1);
    final alignment = nativeConfig?.varint(2);

    if (enabled != 1 || alignment != 2) {
      throw AndroidReleaseBundleValidationException(
        'BundleConfig.pb must enable uncompressed native libraries with '
        'PAGE_ALIGNMENT_16K; found enabled=$enabled, alignment=$alignment.',
      );
    }
  }

  int _minimumLoadAlignment(Uint8List bytes, {required String path}) {
    if (bytes.length < 64 ||
        bytes[0] != 0x7f ||
        bytes[1] != 0x45 ||
        bytes[2] != 0x4c ||
        bytes[3] != 0x46) {
      throw AndroidReleaseBundleValidationException(
        'Native library is not a valid ELF file: $path',
      );
    }

    final elfClass = bytes[4];
    final byteOrder = switch (bytes[5]) {
      1 => Endian.little,
      2 => Endian.big,
      _ => throw AndroidReleaseBundleValidationException(
        'Native library has an unsupported ELF byte order: $path',
      ),
    };
    final data = ByteData.sublistView(bytes);

    final int programHeaderOffset;
    final int programHeaderEntrySize;
    final int programHeaderCount;
    final int alignmentOffset;

    switch (elfClass) {
      case 1:
        programHeaderOffset = _readUint32(data, 28, byteOrder, path);
        programHeaderEntrySize = _readUint16(data, 42, byteOrder, path);
        programHeaderCount = _readUint16(data, 44, byteOrder, path);
        alignmentOffset = 28;
        break;
      case 2:
        programHeaderOffset = _readUint64(data, 32, byteOrder, path);
        programHeaderEntrySize = _readUint16(data, 54, byteOrder, path);
        programHeaderCount = _readUint16(data, 56, byteOrder, path);
        alignmentOffset = 48;
        break;
      default:
        throw AndroidReleaseBundleValidationException(
          'Native library has an unsupported ELF class: $path',
        );
    }

    if (programHeaderCount == 0 || programHeaderCount == 0xffff) {
      throw AndroidReleaseBundleValidationException(
        'Native library has an unsupported ELF program header table: $path',
      );
    }

    int? minimumAlignment;
    for (var index = 0; index < programHeaderCount; index += 1) {
      final headerOffset =
          programHeaderOffset + (index * programHeaderEntrySize);
      final programType = _readUint32(data, headerOffset, byteOrder, path);
      if (programType != 1) {
        continue;
      }

      final alignment = elfClass == 1
          ? _readUint32(data, headerOffset + alignmentOffset, byteOrder, path)
          : _readUint64(data, headerOffset + alignmentOffset, byteOrder, path);
      minimumAlignment = minimumAlignment == null
          ? alignment
          : minimumAlignment < alignment
          ? minimumAlignment
          : alignment;
    }

    if (minimumAlignment == null || minimumAlignment == 0) {
      throw AndroidReleaseBundleValidationException(
        'Native library has no aligned ELF LOAD segments: $path',
      );
    }
    return minimumAlignment;
  }

  int _readUint16(ByteData data, int offset, Endian endian, String path) {
    _requireRange(data, offset, 2, path);
    return data.getUint16(offset, endian);
  }

  int _readUint32(ByteData data, int offset, Endian endian, String path) {
    _requireRange(data, offset, 4, path);
    return data.getUint32(offset, endian);
  }

  int _readUint64(ByteData data, int offset, Endian endian, String path) {
    _requireRange(data, offset, 8, path);
    return data.getUint64(offset, endian);
  }

  void _requireRange(ByteData data, int offset, int length, String path) {
    if (offset < 0 || length < 0 || offset + length > data.lengthInBytes) {
      throw AndroidReleaseBundleValidationException(
        'Native library has a truncated ELF header: $path',
      );
    }
  }
}

class _ProtoMessage {
  _ProtoMessage(this.bytes);

  final Uint8List bytes;

  int? varint(int targetFieldNumber) {
    for (final field in _fields()) {
      if (field.number == targetFieldNumber && field.value is int) {
        return field.value as int;
      }
    }
    return null;
  }

  Uint8List? lengthDelimited(int targetFieldNumber) {
    for (final field in _fields()) {
      if (field.number == targetFieldNumber && field.value is Uint8List) {
        return field.value as Uint8List;
      }
    }
    return null;
  }

  Iterable<_ProtoField> _fields() sync* {
    var offset = 0;
    while (offset < bytes.length) {
      final tag = _readVarint(bytes, offset);
      offset = tag.nextOffset;
      final fieldNumber = tag.value >> 3;
      final wireType = tag.value & 0x07;
      if (fieldNumber == 0) {
        throw const AndroidReleaseBundleValidationException(
          'BundleConfig.pb contains an invalid field number.',
        );
      }

      switch (wireType) {
        case 0:
          final value = _readVarint(bytes, offset);
          offset = value.nextOffset;
          yield _ProtoField(fieldNumber, value.value);
          continue;
        case 1:
          offset = _skip(bytes, offset, 8);
          continue;
        case 2:
          final length = _readVarint(bytes, offset);
          offset = length.nextOffset;
          final end = _skip(bytes, offset, length.value);
          yield _ProtoField(
            fieldNumber,
            Uint8List.sublistView(bytes, offset, end),
          );
          offset = end;
          continue;
        case 5:
          offset = _skip(bytes, offset, 4);
          continue;
        default:
          throw AndroidReleaseBundleValidationException(
            'BundleConfig.pb uses unsupported wire type $wireType.',
          );
      }
    }
  }

  _ProtoVarint _readVarint(Uint8List source, int start) {
    var value = 0;
    var shift = 0;
    var offset = start;
    while (offset < source.length && shift < 64) {
      final byte = source[offset];
      offset += 1;
      value |= (byte & 0x7f) << shift;
      if (byte & 0x80 == 0) {
        return _ProtoVarint(value, offset);
      }
      shift += 7;
    }
    throw const AndroidReleaseBundleValidationException(
      'BundleConfig.pb contains an invalid varint.',
    );
  }

  int _skip(Uint8List source, int start, int length) {
    final end = start + length;
    if (length < 0 || start < 0 || end > source.length) {
      throw const AndroidReleaseBundleValidationException(
        'BundleConfig.pb is truncated.',
      );
    }
    return end;
  }
}

class _ProtoField {
  const _ProtoField(this.number, this.value);

  final int number;
  final Object value;
}

class _ProtoVarint {
  const _ProtoVarint(this.value, this.nextOffset);

  final int value;
  final int nextOffset;
}
