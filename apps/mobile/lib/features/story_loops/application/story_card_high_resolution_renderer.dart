import 'dart:typed_data';
import 'dart:ui' as ui;

import 'story_card_canvas_renderer.dart';
import '../data/story_card_download_failure.dart';
import '../data/story_card_download_source.dart';

abstract interface class StoryCardImageRenderer {
  Future<Uint8List> render(StoryCardDownloadSource source);
}

class StoryCardHighResolutionRenderer implements StoryCardImageRenderer {
  const StoryCardHighResolutionRenderer({
    this.outputWidth = defaultOutputWidth,
    this.outputHeight = defaultOutputHeight,
  });

  static const defaultOutputWidth = 1440;
  static const defaultOutputHeight = 1800;

  final int outputWidth;
  final int outputHeight;

  @override
  Future<Uint8List> render(StoryCardDownloadSource source) async {
    ui.Codec? backgroundCodec;
    ui.Image? backgroundImage;
    ui.Picture? picture;
    ui.Image? outputImage;

    try {
      final backgroundBytes = source.backgroundImageBytes;
      if (backgroundBytes != null) {
        try {
          backgroundCodec = await ui.instantiateImageCodec(backgroundBytes);
          final frame = await backgroundCodec.getNextFrame();
          backgroundImage = frame.image;
        } catch (error) {
          throw StoryCardDownloadException(
            StoryCardDownloadFailureReason.invalidSource,
            error.toString(),
          );
        }
      }

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      StoryCardCanvasRenderer.paint(
        canvas: canvas,
        size: ui.Size(outputWidth.toDouble(), outputHeight.toDouble()),
        scene: source.scene,
        backgroundImage: backgroundImage,
      );
      picture = recorder.endRecording();
      outputImage = await picture.toImage(outputWidth, outputHeight);
      final byteData = await outputImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        throw const StoryCardDownloadException(
          StoryCardDownloadFailureReason.renderFailed,
        );
      }

      return byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
    } on StoryCardDownloadException {
      rethrow;
    } catch (error) {
      throw StoryCardDownloadException(
        StoryCardDownloadFailureReason.renderFailed,
        error.toString(),
      );
    } finally {
      outputImage?.dispose();
      picture?.dispose();
      backgroundImage?.dispose();
      backgroundCodec?.dispose();
    }
  }
}
