import 'package:flutter/material.dart';

class HomeForegroundPortal extends StatefulWidget {
  const HomeForegroundPortal({
    required this.portalKey,
    required this.placeholder,
    required this.child,
    this.layoutKey,
    super.key,
  });

  final Key portalKey;
  final Widget placeholder;
  final Widget child;
  final Object? layoutKey;

  @override
  State<HomeForegroundPortal> createState() => _HomeForegroundPortalState();
}

class _HomeForegroundPortalState extends State<HomeForegroundPortal> {
  late final OverlayPortalController _controller = OverlayPortalController()
    ..show();
  final GlobalKey _placeholderKey = GlobalKey();
  Object? _layoutSignature;
  Size? _placeholderSize;
  bool _measurementScheduled = false;
  bool _showScheduled = false;

  bool _isCoveredByPage() {
    final route = ModalRoute.of(context);
    final secondaryAnimation = route?.secondaryAnimation;
    return ModalRoute.isCurrentOf(context) == false &&
        secondaryAnimation != null &&
        secondaryAnimation.status != AnimationStatus.dismissed;
  }

  void _scheduleShow() {
    if (_controller.isShowing || _showScheduled) {
      return;
    }
    _showScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showScheduled = false;
      if (!mounted || _controller.isShowing || _isCoveredByPage()) {
        return;
      }
      _controller.show();
    });
  }

  void _schedulePlaceholderMeasurement() {
    if (_measurementScheduled) {
      return;
    }
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted || _placeholderSize != null) {
        return;
      }
      final renderObject = _placeholderKey.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) {
        return;
      }
      setState(() {
        _placeholderSize = renderObject.size;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCoveredByPage()) {
      return widget.child;
    }
    _scheduleShow();

    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutSignature = (
          widget.layoutKey,
          constraints,
          MediaQuery.textScalerOf(context),
          Directionality.of(context),
          Localizations.maybeLocaleOf(context),
          DefaultTextStyle.of(context).style,
        );
        if (_layoutSignature != layoutSignature) {
          _layoutSignature = layoutSignature;
          _placeholderSize = null;
        }
        final placeholderSize = _placeholderSize;
        if (placeholderSize == null) {
          _schedulePlaceholderMeasurement();
        }

        return OverlayPortal.overlayChildLayoutBuilder(
          key: widget.portalKey,
          controller: _controller,
          overlayChildBuilder: (context, info) {
            final offset = MatrixUtils.transformPoint(
              info.childPaintTransform,
              Offset.zero,
            );
            return Positioned(
              left: offset.dx,
              top: offset.dy,
              width: info.childSize.width,
              height: info.childSize.height,
              child: widget.child,
            );
          },
          child: placeholderSize == null
              ? KeyedSubtree(key: _placeholderKey, child: widget.placeholder)
              : SizedBox.fromSize(size: placeholderSize),
        );
      },
    );
  }
}
