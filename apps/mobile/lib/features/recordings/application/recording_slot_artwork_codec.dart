import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;

import '../../../core/drawing/app_drawing.dart';
import '../../../core/drawing/app_drawing_painter.dart';

class RecordingSlotArtworkArtifact {
  const RecordingSlotArtworkArtifact({
    required this.previewBytes,
    required this.drawingDataBytes,
  });

  final Uint8List previewBytes;
  final Uint8List drawingDataBytes;
}

class RecordingSlotArtworkCodec {
  const RecordingSlotArtworkCodec();

  static const previewSize = 256;
  static const maxObjectBytes = 256 * 1024;
  static const maxDecodedDrawingBytes = 2 * 1024 * 1024;
  static const maxStrokeCount = 512;
  static const maxPointsPerStroke = 10000;
  static const maxTotalPointCount = 50000;

  Future<RecordingSlotArtworkArtifact> encode(AppDrawingData drawing) async {
    if (!drawing.hasVisibleContent) {
      throw StateError('A visible drawing is required.');
    }

    final rawRgba = await _renderRawRgba(drawing);
    final previewBytes = await compute(_encodeLosslessWebP, rawRgba);
    final drawingDataBytes = Uint8List.fromList(
      gzip.encode(utf8.encode(drawing.toJsonString())),
    );

    if (previewBytes.length > maxObjectBytes ||
        drawingDataBytes.length > maxObjectBytes) {
      throw StateError('Recording slot artwork exceeds its storage limit.');
    }

    return RecordingSlotArtworkArtifact(
      previewBytes: previewBytes,
      drawingDataBytes: drawingDataBytes,
    );
  }

  Future<AppDrawingData> decodeDrawingData(Uint8List bytes) {
    if (bytes.length > maxObjectBytes) {
      throw const FormatException(
        'Recording slot artwork exceeds its compressed data limit.',
      );
    }

    return compute(_decodeDrawingData, bytes);
  }

  Future<Uint8List> _renderRawRgba(AppDrawingData drawing) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size.square(previewSize.toDouble());
    AppDrawingPainter(strokes: drawing.strokes).paint(canvas, size);

    final picture = recorder.endRecording();
    final renderedImage = await picture.toImage(previewSize, previewSize);
    try {
      final byteData = await renderedImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) {
        throw StateError('Recording slot artwork export failed.');
      }

      return byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
    } finally {
      renderedImage.dispose();
      picture.dispose();
    }
  }
}

AppDrawingData _decodeDrawingData(Uint8List bytes) {
  final decodedBytes = _decodeGzipWithLimit(
    bytes,
    RecordingSlotArtworkCodec.maxDecodedDrawingBytes,
  );
  final decodedJson = jsonDecode(utf8.decode(decodedBytes));
  if (decodedJson is! Map) {
    throw const FormatException('Recording slot artwork must be an object.');
  }

  final json = Map<String, dynamic>.from(decodedJson);
  _validateDrawingJson(json);
  return AppDrawingData.fromJson(json);
}

Uint8List _decodeGzipWithLimit(Uint8List bytes, int maxBytes) {
  final sink = _BoundedByteSink(maxBytes);
  try {
    final decoder = gzip.decoder.startChunkedConversion(sink);
    decoder.add(bytes);
    decoder.close();
  } on FormatException {
    rethrow;
  } catch (error) {
    throw FormatException('Invalid recording slot artwork gzip data.', error);
  }
  return sink.takeBytes();
}

void _validateDrawingJson(Map<String, dynamic> json) {
  if (json['version'] != 1) {
    throw const FormatException('Unsupported recording slot artwork version.');
  }

  final strokes = json['strokes'];
  if (strokes is! List) {
    throw const FormatException('Recording slot artwork strokes are invalid.');
  }
  if (strokes.length > RecordingSlotArtworkCodec.maxStrokeCount) {
    throw const FormatException(
      'Recording slot artwork contains too many strokes.',
    );
  }

  var totalPointCount = 0;
  for (final rawStroke in strokes) {
    if (rawStroke is! Map) {
      throw const FormatException('Recording slot artwork stroke is invalid.');
    }
    final stroke = Map<String, dynamic>.from(rawStroke);
    if (stroke['tool'] != 'pen' && stroke['tool'] != 'eraser') {
      throw const FormatException('Recording slot artwork tool is invalid.');
    }

    final color = stroke['color'];
    if (color is! String || !_colorPattern.hasMatch(color)) {
      throw const FormatException('Recording slot artwork color is invalid.');
    }

    final rawWidth = stroke['width'];
    if (rawWidth is! num) {
      throw const FormatException('Recording slot artwork width is invalid.');
    }
    final width = rawWidth.toDouble();
    if (!width.isFinite || width <= 0 || width > 1) {
      throw const FormatException('Recording slot artwork width is invalid.');
    }

    final points = stroke['points'];
    if (points is! List) {
      throw const FormatException('Recording slot artwork points are invalid.');
    }
    if (points.length > RecordingSlotArtworkCodec.maxPointsPerStroke) {
      throw const FormatException(
        'Recording slot artwork stroke contains too many points.',
      );
    }
    totalPointCount += points.length;
    if (totalPointCount > RecordingSlotArtworkCodec.maxTotalPointCount) {
      throw const FormatException(
        'Recording slot artwork contains too many points.',
      );
    }

    for (final rawPoint in points) {
      if (rawPoint is! Map) {
        throw const FormatException('Recording slot artwork point is invalid.');
      }
      final point = Map<String, dynamic>.from(rawPoint);
      _validateNormalizedCoordinate(point['x']);
      _validateNormalizedCoordinate(point['y']);
    }
  }
}

void _validateNormalizedCoordinate(Object? rawValue) {
  if (rawValue is! num) {
    throw const FormatException(
      'Recording slot artwork coordinate is invalid.',
    );
  }
  final value = rawValue.toDouble();
  if (!value.isFinite || value < 0 || value > 1) {
    throw const FormatException(
      'Recording slot artwork coordinate is outside the canvas.',
    );
  }
}

final _colorPattern = RegExp(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$');

class _BoundedByteSink extends ByteConversionSinkBase {
  _BoundedByteSink(this.maxBytes);

  final int maxBytes;
  final BytesBuilder _bytes = BytesBuilder(copy: false);
  var _length = 0;
  var _isClosed = false;

  @override
  void add(List<int> chunk) {
    if (_isClosed) {
      throw StateError('Cannot add data after the sink is closed.');
    }
    _length += chunk.length;
    if (_length > maxBytes) {
      throw const FormatException(
        'Recording slot artwork exceeds its decoded data limit.',
      );
    }
    _bytes.add(chunk);
  }

  @override
  void close() {
    _isClosed = true;
  }

  Uint8List takeBytes() => _bytes.takeBytes();
}

Uint8List _encodeLosslessWebP(Uint8List rawRgba) {
  final preview = image.Image.fromBytes(
    width: RecordingSlotArtworkCodec.previewSize,
    height: RecordingSlotArtworkCodec.previewSize,
    bytes: rawRgba.buffer,
    bytesOffset: rawRgba.offsetInBytes,
    numChannels: 4,
    order: image.ChannelOrder.rgba,
  );
  return image.encodeWebP(preview);
}
