import 'package:flutter/material.dart';

import 'app_loading_indicator.dart';

class AppMediaReveal extends StatefulWidget {
  const AppMediaReveal({
    super.key,
    required this.ready,
    required this.child,
    this.synchronous = false,
    this.loadingBuilder,
  });

  final bool ready;
  final bool synchronous;
  final Widget child;
  final WidgetBuilder? loadingBuilder;

  @override
  State<AppMediaReveal> createState() => _AppMediaRevealState();
}

class _AppMediaRevealState extends State<AppMediaReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 0.88,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  @override
  void didUpdateWidget(AppMediaReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ready != widget.ready ||
        oldWidget.synchronous != widget.synchronous) {
      _update();
    }
  }

  void _update() {
    if (!widget.ready) {
      _controller.value = 0;
    } else if (widget.synchronous || MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.ready) {
      if (widget.loadingBuilder case final builder?) return builder(context);
      return const Center(
        child: SizedBox.square(
          dimension: 18,
          child: AppLoadingIndicator(radius: 8),
        ),
      );
    }
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
