import 'dart:math' as math;

import 'package:flutter/material.dart';

typedef AppNetworkImageFallbackBuilder = Widget Function(BuildContext context);

class AppSizedNetworkImage extends StatelessWidget {
  const AppSizedNetworkImage({
    super.key,
    required this.url,
    required this.logicalSize,
    required this.fallbackBuilder,
    this.cacheLogicalSize,
    this.gaplessPlayback = false,
    this.fit = BoxFit.contain,
  });

  final String? url;
  final Size logicalSize;
  final AppNetworkImageFallbackBuilder fallbackBuilder;
  final Size? cacheLogicalSize;
  final bool gaplessPlayback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = url;
    final uri = resolvedUrl == null ? null : Uri.tryParse(resolvedUrl);
    final resolvedCacheLogicalSize = cacheLogicalSize ?? logicalSize;
    if (resolvedUrl == null ||
        uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        !_isUsableSize(logicalSize) ||
        !_isUsableSize(resolvedCacheLogicalSize)) {
      return fallbackBuilder(context);
    }

    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = math.max(
      1,
      (resolvedCacheLogicalSize.width * pixelRatio).round(),
    );
    final cacheHeight = math.max(
      1,
      (resolvedCacheLogicalSize.height * pixelRatio).round(),
    );

    return Image.network(
      resolvedUrl,
      width: logicalSize.width,
      height: logicalSize.height,
      fit: fit,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      gaplessPlayback: gaplessPlayback,
      errorBuilder: (context, error, stackTrace) => fallbackBuilder(context),
    );
  }
}

bool _isUsableSize(Size size) {
  return size.width.isFinite && size.height.isFinite && !size.isEmpty;
}
