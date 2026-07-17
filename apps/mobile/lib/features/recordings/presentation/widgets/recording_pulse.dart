import 'package:flutter/material.dart';

class RecordingPulse extends StatefulWidget {
  const RecordingPulse({
    super.key,
    required this.noticeKey,
    required this.isRepeating,
    required this.isDisabled,
    required this.child,
    this.transitionKey,
  });

  final Object? noticeKey;
  final bool isRepeating;
  final bool isDisabled;
  final Widget child;
  final Key? transitionKey;

  @override
  State<RecordingPulse> createState() => _RecordingPulseState();
}

class _RecordingPulseState extends State<RecordingPulse>
    with SingleTickerProviderStateMixin {
  static const _pulseDuration = Duration(milliseconds: 320);
  static const _noticePulsePeriods = 6;

  late final AnimationController _controller;
  late final Animation<double> _scale;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _pulseDuration);
    _scale = Tween<double>(
      begin: 1,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _synchronize(initial: true);
  }

  @override
  void didUpdateWidget(covariant RecordingPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    final noticeChanged = oldWidget.noticeKey != widget.noticeKey;
    if (noticeChanged ||
        oldWidget.isRepeating != widget.isRepeating ||
        oldWidget.isDisabled != widget.isDisabled) {
      _synchronize(notify: noticeChanged && widget.noticeKey != null);
    }
  }

  @override
  void dispose() {
    _generation += 1;
    _controller.dispose();
    super.dispose();
  }

  void _synchronize({bool initial = false, bool notify = false}) {
    final generation = ++_generation;
    _controller.stop();
    _controller.value = 0;

    if (widget.isDisabled) {
      return;
    }
    if (widget.isRepeating) {
      _controller.repeat(reverse: true);
      return;
    }
    if ((initial || notify) && widget.noticeKey != null) {
      final ticker = _controller.repeat(
        reverse: true,
        count: _noticePulsePeriods,
      );
      ticker.whenCompleteOrCancel(() {
        if (!mounted ||
            generation != _generation ||
            widget.isRepeating ||
            widget.isDisabled) {
          return;
        }
        _controller.value = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      key: widget.transitionKey,
      scale: _scale,
      child: widget.child,
    );
  }
}
