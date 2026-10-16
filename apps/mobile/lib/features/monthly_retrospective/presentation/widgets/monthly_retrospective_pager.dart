import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class MonthlyRetrospectivePager extends StatefulWidget {
  const MonthlyRetrospectivePager({
    super.key,
    required this.month,
    required this.pages,
    required this.pageBuilder,
  });

  final DateTime month;
  final List<String> pages;
  final Widget Function(String page) pageBuilder;

  @override
  State<MonthlyRetrospectivePager> createState() =>
      _MonthlyRetrospectivePagerState();
}

class _MonthlyRetrospectivePagerState extends State<MonthlyRetrospectivePager> {
  late String _selected = widget.pages.first;
  PageController _controller = PageController(keepPage: false);

  @override
  void didUpdateWidget(MonthlyRetrospectivePager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month != widget.month ||
        !listEquals(oldWidget.pages, widget.pages)) {
      if (oldWidget.month != widget.month ||
          !widget.pages.contains(_selected)) {
        _selected = widget.pages.first;
      }
      final previous = _controller;
      _controller = PageController(
        initialPage: widget.pages.indexOf(_selected),
        keepPage: false,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectPage(int index) {
    FocusScope.of(context).unfocus();
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  String _pageDescription(int index) =>
      '${widget.pages[index]}, ${index + 1}/${widget.pages.length}페이지';

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: PageView.builder(
          key: ValueKey('${widget.month}:${widget.pages.join('|')}'),
          controller: _controller,
          allowImplicitScrolling: true,
          itemCount: widget.pages.length,
          onPageChanged: (index) {
            FocusScope.of(context).unfocus();
            setState(() => _selected = widget.pages[index]);
          },
          itemBuilder: (context, index) =>
              widget.pageBuilder(widget.pages[index]),
        ),
      ),
      if (widget.pages.length > 1)
        SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: Semantics(
              label: '월간 회고 페이지',
              value: _pageDescription(widget.pages.indexOf(_selected)),
              increasedValue:
                  widget.pages.indexOf(_selected) + 1 < widget.pages.length
                  ? _pageDescription(widget.pages.indexOf(_selected) + 1)
                  : null,
              decreasedValue: widget.pages.indexOf(_selected) > 0
                  ? _pageDescription(widget.pages.indexOf(_selected) - 1)
                  : null,
              slider: true,
              onIncrease:
                  widget.pages.indexOf(_selected) + 1 < widget.pages.length
                  ? () => _selectPage(widget.pages.indexOf(_selected) + 1)
                  : null,
              onDecrease: widget.pages.indexOf(_selected) > 0
                  ? () => _selectPage(widget.pages.indexOf(_selected) - 1)
                  : null,
              child: ExcludeSemantics(
                child: GestureDetector(
                  key: const Key('monthly-page-control'),
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTapUp: (details) => _selectPage(
                    (details.localPosition.dx / 18).floor().clamp(
                      0,
                      widget.pages.length - 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var index = 0; index < widget.pages.length; index++)
                        GestureDetector(
                          key: Key('monthly-page-indicator-$index'),
                          behavior: HitTestBehavior.opaque,
                          excludeFromSemantics: true,
                          onTap: () => _selectPage(index),
                          child: SizedBox(
                            width: 18,
                            height: 44,
                            child: Transform.translate(
                              offset: const Offset(0, 8),
                              child: Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: widget.pages[index] == _selected
                                        ? AppColors.textMuted
                                        : AppColors.textMuted.withValues(
                                            alpha: 0.25,
                                          ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
