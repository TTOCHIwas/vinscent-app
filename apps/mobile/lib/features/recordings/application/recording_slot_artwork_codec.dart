import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;

import '../../characters/data/character_drawing.dart';
import '../../characters/presentation/widgets/character_canvas.dart';

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

  Future<RecordingSlotArtworkArtifact> encode(
    CharacterDrawingData drawing,
  ) async {
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

  CharacterDrawingData decodeDrawingData(Uint8List bytes) {
    final json = utf8.decode(gzip.decode(bytes));
    return CharacterDrawingData.fromJsonString(json);
  }

  Future<Uint8List> _renderRawRgba(CharacterDrawingData drawing) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size.square(previewSize.toDouble());
    CharacterDrawingPainter(strokes: drawing.strokes).paint(canvas, size);

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
