import 'package:flutter/material.dart';

class AppInitialReveal extends StatefulWidget {
  const AppInitialReveal({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 220),
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;

  @override
  State<AppInitialReveal> createState() => _AppInitialRevealState();
}

class _AppInitialRevealState extends State<AppInitialReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _opacity;
  bool _didScheduleReveal = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _updateOpacity();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didScheduleReveal) {
      return;
    }
    _didScheduleReveal = true;

    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    if (animationsDisabled || widget.duration == Duration.zero) {
      _controller.value = 1;
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void didUpdateWidget(covariant AppInitialReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.curve != widget.curve) {
      _updateOpacity();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }

  void _updateOpacity() {
    _opacity = _controller.drive(CurveTween(curve: widget.curve));
  }
}
