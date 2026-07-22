import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../application/home_guide.dart';

typedef HomeGuideRotatorBuilder =
    Widget Function(HomeGuide? guide, double opacity, VoidCallback? onTap);

class HomeGuideRotator extends StatefulWidget {
  const HomeGuideRotator({
    super.key,
    required this.guides,
    required this.onGuideTap,
    required this.builder,
  });

  static const displayDuration = Duration(seconds: 6);
  static const fadeDuration = Duration(milliseconds: 220);

  final List<HomeGuide> guides;
  final ValueChanged<HomeGuide> onGuideTap;
  final HomeGuideRotatorBuilder builder;

  @override
  State<HomeGuideRotator> createState() => _HomeGuideRotatorState();
}

class _HomeGuideRotatorState extends State<HomeGuideRotator> {
  Timer? _displayTimer;
  Timer? _fadeTimer;
  var _index = 0;
  var _opacity = 1.0;
  var _completed = false;
  var _isTransitioning = false;

  HomeGuide? get _currentGuide {
    if (_completed || widget.guides.isEmpty || _index >= widget.guides.length) {
      return null;
    }
    return widget.guides[_index];
  }

  @override
  void initState() {
    super.initState();
    _completed = widget.guides.isEmpty;
    _scheduleCurrentGuide();
  }

  @override
  void didUpdateWidget(covariant HomeGuideRotator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.guides, widget.guides)) {
      _restart();
    }
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guide = _currentGuide;
    return widget.builder(
      guide,
      guide == null ? 0 : _opacity,
      guide == null || guide.action == HomeGuideAction.none
          ? null
          : _selectCurrentGuide,
    );
  }

  void _restart() {
    _cancelTimers();
    _index = 0;
    _opacity = 1;
    _completed = widget.guides.isEmpty;
    _isTransitioning = false;
    _scheduleCurrentGuide();
  }

  void _scheduleCurrentGuide() {
    if (_currentGuide == null) {
      return;
    }
    _displayTimer = Timer(HomeGuideRotator.displayDuration, _beginTransition);
  }

  void _selectCurrentGuide() {
    final guide = _currentGuide;
    if (guide == null) {
      return;
    }
    widget.onGuideTap(guide);
    _beginTransition();
  }

  void _beginTransition() {
    if (!mounted || _currentGuide == null || _isTransitioning) {
      return;
    }
    _displayTimer?.cancel();
    _isTransitioning = true;
    setState(() => _opacity = 0);
    _fadeTimer = Timer(HomeGuideRotator.fadeDuration, _showNextGuide);
  }

  void _showNextGuide() {
    if (!mounted) {
      return;
    }
    setState(() {
      _isTransitioning = false;
      if (_index + 1 >= widget.guides.length) {
        _completed = true;
        return;
      }
      _index += 1;
      _opacity = 1;
    });
    _scheduleCurrentGuide();
  }

  void _cancelTimers() {
    _displayTimer?.cancel();
    _fadeTimer?.cancel();
    _displayTimer = null;
    _fadeTimer = null;
  }
}
