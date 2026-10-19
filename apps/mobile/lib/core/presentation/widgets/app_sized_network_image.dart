import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_media_reveal.dart';
import 'app_network_image.dart';
import 'app_media_loading_group.dart';

typedef AppNetworkImageFallbackBuilder = Widget Function(BuildContext context);

class AppSizedNetworkImage extends StatefulWidget {
  const AppSizedNetworkImage({
    super.key,
    required this.url,
    required this.logicalSize,
    required this.fallbackBuilder,
    this.cacheLogicalSize,
    this.gaplessPlayback = false,
    this.fit = BoxFit.contain,
    this.surfaceBuilder,
  });

  final String? url;
  final Size logicalSize;
  final AppNetworkImageFallbackBuilder fallbackBuilder;
  final Size? cacheLogicalSize;
  final bool gaplessPlayback;
  final BoxFit fit;
  final Widget Function(BuildContext context, Widget image)? surfaceBuilder;

  @override
  State<AppSizedNetworkImage> createState() => _AppSizedNetworkImageState();
}

class _AppSizedNetworkImageState extends State<AppSizedNetworkImage> {
  var _hasFrame = false;
  AppMediaLoadingTracker? _loadingGroup;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final group = AppMediaLoadingGroup.maybeOf(context);
    if (!identical(group, _loadingGroup)) {
      _loadingGroup?.update(this, loading: false);
      _loadingGroup = group;
    }
  }

  @override
  void dispose() {
    _loadingGroup?.update(this, loading: false);
    super.dispose();
  }

  @override
  void didUpdateWidget(AppSizedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url && !widget.gaplessPlayback) {
      _hasFrame = false;
      _loadingGroup?.update(this, loading: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = widget.url;
    final uri = resolvedUrl == null ? null : Uri.tryParse(resolvedUrl);
    final logicalSize = widget.logicalSize;
    final resolvedCacheLogicalSize = widget.cacheLogicalSize ?? logicalSize;
    if (resolvedUrl == null ||
        uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        !_isUsableSize(logicalSize) ||
        !_isUsableSize(resolvedCacheLogicalSize)) {
      _hasFrame = false;
      _loadingGroup?.update(this, loading: false);
      final fallback = widget.fallbackBuilder(context);
      final surface =
          widget.surfaceBuilder?.call(context, fallback) ?? fallback;
      return _loadingGroup == null
          ? surface
          : _revealSurface(surface, ready: true, synchronous: true);
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

    return SizedBox.fromSize(
      size: logicalSize,
      child: Image(
        image: ResizeImage.resizeIfNeeded(
          cacheWidth,
          cacheHeight,
          AppNetworkImage(resolvedUrl),
        ),
        width: logicalSize.width,
        height: logicalSize.height,
        fit: widget.fit,
        gaplessPlayback: widget.gaplessPlayback,
        frameBuilder: (context, child, frame, synchronous) {
          if (frame != null) _hasFrame = true;
          final ready = frame != null || (widget.gaplessPlayback && _hasFrame);
          _loadingGroup?.update(this, loading: !ready);
          final surface = widget.surfaceBuilder?.call(context, child) ?? child;
          return _revealSurface(
            surface,
            ready: ready,
            synchronous: synchronous,
          );
        },
        errorBuilder: (context, error, stackTrace) {
          _loadingGroup?.update(this, loading: false);
          final fallback = widget.fallbackBuilder(context);
          final surface =
              widget.surfaceBuilder?.call(context, fallback) ?? fallback;
          return _loadingGroup == null
              ? surface
              : _revealSurface(surface, ready: true, synchronous: true);
        },
      ),
    );
  }

  Widget _revealSurface(
    Widget surface, {
    required bool ready,
    required bool synchronous,
  }) {
    final group = _loadingGroup;
    if (group == null) {
      return AppMediaReveal(
        ready: ready,
        synchronous: synchronous,
        child: surface,
      );
    }
    return AnimatedBuilder(
      animation: group,
      builder: (context, _) => AppMediaReveal(
        ready: ready && group.canReveal,
        synchronous: synchronous,
        loadingBuilder: (_) => const SizedBox.expand(),
        child: surface,
      ),
    );
  }
}

bool _isUsableSize(Size size) {
  return size.width.isFinite && size.height.isFinite && !size.isEmpty;
}
