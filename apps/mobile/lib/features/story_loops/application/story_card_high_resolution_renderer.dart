import 'dart:typed_data';
import 'dart:ui' as ui;

import 'story_card_canvas_renderer.dart';
import 'story_card_film_shader.dart';
import '../data/story_card_download_failure.dart';
import '../data/story_card_download_source.dart';
import '../data/story_card_film_look.dart';

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
    final compositeImageBytes = source.compositeImageBytes;
    if (source.scene.cardType.isFourCut && compositeImageBytes != null) {
      return compositeImageBytes;
    }

    ui.Codec? backgroundCodec;
    ui.Image? backgroundImage;
    ui.Picture? picture;
    ui.Image? outputImage;
    ui.FragmentProgram? filmProgram;

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

      if (backgroundImage != null &&
          source.scene.photoFilms.any(
            (film) => film.look != StoryCardFilmLook.original,
          )) {
        filmProgram = await StoryCardFilmShaderProgram.load();
      }

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      StoryCardCanvasRenderer.paint(
        canvas: canvas,
        size: ui.Size(outputWidth.toDouble(), outputHeight.toDouble()),
        scene: source.scene,
        backgroundImage: backgroundImage,
        filmProgram: filmProgram,
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
