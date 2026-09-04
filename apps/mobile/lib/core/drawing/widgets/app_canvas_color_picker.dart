import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'app_color_sampler.dart';

Future<Color?> showAppCanvasColorPicker({
  required BuildContext context,
  required GlobalKey canvasKey,
  required Color backgroundColor,
  required String keyPrefix,
  bool Function()? canOpen,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final sourceRoute = ModalRoute.of(context);
  ui.Image? snapshot;
  try {
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted || canOpen?.call() == false) return null;
    if (!navigator.mounted) return null;

    final boundary = canvasKey.currentContext?.findRenderObject();
    final overlay = navigator.overlay?.context.findRenderObject();
    if (boundary is! RenderRepaintBoundary || overlay is! RenderBox) {
      throw StateError('The drawing canvas is unavailable.');
    }

    final canvasRect =
        overlay.globalToLocal(boundary.localToGlobal(Offset.zero)) &
        boundary.size;
    final viewport = overlay.size;
    final captured = await boundary.toImage(pixelRatio: 1);
    snapshot = captured;
    final bytes = await captured.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) throw StateError('The drawing capture is unavailable.');
    if (!context.mounted ||
        !navigator.mounted ||
        sourceRoute?.isCurrent == false ||
        canOpen?.call() == false) {
      return null;
    }

    final buffer = AppColorSampleBuffer(
      width: captured.width,
      height: captured.height,
      rgbaBytes: bytes.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      ),
    );
    final route = PageRouteBuilder<Color>(
      fullscreenDialog: true,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, _, _) => ColoredBox(
        color: backgroundColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = math.min(
              constraints.maxWidth / viewport.width,
              constraints.maxHeight / viewport.height,
            );
            final offset = Offset(
              (constraints.maxWidth - viewport.width * scale) / 2,
              (constraints.maxHeight - viewport.height * scale) / 2,
            );
            final rect = Rect.fromLTWH(
              offset.dx + canvasRect.left * scale,
              offset.dy + canvasRect.top * scale,
              canvasRect.width * scale,
              canvasRect.height * scale,
            );
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fromRect(
                  rect: rect,
                  child: RawImage(image: captured, fit: BoxFit.fill),
                ),
                AppColorSampler(
                  key: ValueKey('$keyPrefix-eyedropper-overlay'),
                  keyPrefix: keyPrefix,
                  sampleBuffer: buffer,
                  canvasRect: rect,
                  onColorSelected: (color) => Navigator.of(context).pop(color),
                ),
              ],
            );
          },
        ),
      ),
    );
    final color = await navigator.push(route);
    // RawImage keeps the snapshot until the picker route is fully removed.
    await route.completed;
    return color;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('색상을 가져오지 못했어요.')));
    }
    return null;
  } finally {
    snapshot?.dispose();
  }
}
