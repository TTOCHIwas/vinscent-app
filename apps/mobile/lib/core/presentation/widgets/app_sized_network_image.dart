import 'dart:math' as math;

import 'package:flutter/material.dart';

typedef AppNetworkImageFallbackBuilder = Widget Function(BuildContext context);

class AppSizedNetworkImage extends StatelessWidget {
  const AppSizedNetworkImage({
    super.key,
    required this.url,
    required this.logicalSize,
    required this.fallbackBuilder,
    this.fit = BoxFit.contain,
  });

  final String? url;
  final Size logicalSize;
  final AppNetworkImageFallbackBuilder fallbackBuilder;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = url;
    final uri = resolvedUrl == null ? null : Uri.tryParse(resolvedUrl);
    if (resolvedUrl == null ||
        uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        !logicalSize.width.isFinite ||
        !logicalSize.height.isFinite ||
        logicalSize.isEmpty) {
      return fallbackBuilder(context);
    }

    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = math.max(1, (logicalSize.width * pixelRatio).round());
    final cacheHeight = math.max(1, (logicalSize.height * pixelRatio).round());

    return Image.network(
      resolvedUrl,
      width: logicalSize.width,
      height: logicalSize.height,
      fit: fit,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      errorBuilder: (context, error, stackTrace) => fallbackBuilder(context),
    );
  }
}
